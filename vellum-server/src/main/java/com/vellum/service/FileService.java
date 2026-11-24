package com.vellum.service;

import com.vellum.common.BizException;
import com.vellum.dto.UploadFileResponse;
import com.vellum.entity.PostImage;
import com.vellum.mapper.PostImageMapper;
import io.minio.BucketExistsArgs;
import io.minio.GetObjectArgs;
import io.minio.MakeBucketArgs;
import io.minio.MinioClient;
import io.minio.PutObjectArgs;
import io.minio.RemoveObjectArgs;
import io.minio.errors.ErrorResponseException;
import lombok.extern.slf4j.Slf4j;
import net.coobird.thumbnailator.Thumbnails;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import javax.imageio.ImageIO;
import java.awt.image.BufferedImage;
import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.time.format.DateTimeFormatter;
import java.util.Locale;
import java.util.UUID;

/**
 * 图片压缩与 MinIO 对象存储服务。
 */
@Service
@Slf4j
public class FileService {

    public static final String FILE_URL_PREFIX = "/api/v1/files/";
    private static final long MAX_IMAGE_BYTES = 20L * 1024 * 1024;
    private static final int MAX_EDGE = 1920;
    private static final float JPEG_QUALITY = 0.82f;
    private static final DateTimeFormatter OBJECT_DIR_FORMAT = DateTimeFormatter.ofPattern("yyyy/MM");
    private static final MediaType MEDIA_TYPE_WEBP = MediaType.parseMediaType("image/webp");

    private final MinioClient minioClient;
    private final PostImageMapper postImageMapper;
    private final String bucket;

    public FileService(
            MinioClient minioClient,
            PostImageMapper postImageMapper,
            @Value("${vellum.minio.bucket:vellum}") String bucket) {
        this.minioClient = minioClient;
        this.postImageMapper = postImageMapper;
        this.bucket = bucket;
    }

    public static String buildImageUrl(String id) {
        return FILE_URL_PREFIX + id;
    }

    /**
     * 校验格式、压缩图片并上传至 MinIO，随后写入未绑定的 post_image 记录。
     */
    public UploadFileResponse upload(MultipartFile file) {
        if (file == null || file.isEmpty()) {
            throw new BizException(400, "上传图片不能为空");
        }
        if (file.getSize() > MAX_IMAGE_BYTES) {
            throw new BizException(400, "单张图片大小不能超过 20MB");
        }

        String ext = resolveExtension(file);
        String contentType = resolveMediaTypeByExt(ext).toString();
        byte[] imageData = compressImage(file, ext);

        OffsetDateTime now = OffsetDateTime.now(ZoneOffset.UTC);
        String id = UUID.randomUUID().toString();
        String objectName = OBJECT_DIR_FORMAT.format(now) + "/" + id + "." + ext;

        try (ByteArrayInputStream inputStream = new ByteArrayInputStream(imageData)) {
            createBucket(bucket);
            minioClient.putObject(
                    PutObjectArgs.builder()
                            .bucket(bucket)
                            .object(objectName)
                            .stream(inputStream, inputStream.available(), -1)
                            .contentType(contentType)
                            .build()
            );
        } catch (Exception e) {
            log.error("MinIO 上传失败, objectName={}", objectName, e);
            throw new BizException(500, "图片上传存储失败");
        }

        PostImage entity = new PostImage();
        entity.setId(id);
        entity.setPostId(null);
        entity.setObjectName(objectName);
        entity.setSortOrder(0);
        entity.setDeleted(false);
        entity.setCreatedAt(now);

        try {
            postImageMapper.insertImage(entity);
        } catch (Exception e) {
            removeObjectQuietly(objectName);
            throw e;
        }

        return new UploadFileResponse(id, buildImageUrl(id));
    }

    /**
     * 查询单条有效图片的元数据，供 Controller 在响应前做 ETag 缓存协商。
     */
    public PostImage getActiveImageMeta(String id) {
        String cleanId = id == null ? "" : id.trim();
        if (cleanId.isEmpty()) {
            throw new BizException(400, "图片 ID 不能为空");
        }
        PostImage meta = postImageMapper.selectActiveById(cleanId);
        if (meta == null) {
            throw new BizException(404, "图片不存在");
        }
        return meta;
    }

    /**
     * 从私有 MinIO Bucket 打开图片流，由控制器直接输出二进制内容。
     */
    public ImageStreamResult openImageStream(PostImage meta) {
        try {
            InputStream stream = minioClient.getObject(
                    GetObjectArgs.builder()
                            .bucket(bucket)
                            .object(meta.getObjectName())
                            .build()
            );
            return new ImageStreamResult(meta.getId(), resolveMediaTypeByExt(meta.getObjectName()), stream);
        } catch (ErrorResponseException e) {
            String code = e.errorResponse() != null ? e.errorResponse().code() : "";
            if ("NoSuchKey".equals(code) || "NoSuchBucket".equals(code)) {
                throw new BizException(404, "图片不存在");
            }
            log.error("读取 MinIO 图片异常, id={}, code={}", meta.getId(), code, e);
            throw new BizException(500, "读取图片失败");
        } catch (Exception e) {
            log.error("读取 MinIO 图片异常, id={}", meta.getId(), e);
            throw new BizException(500, "读取图片失败");
        }
    }

    private void createBucket(String bucketName) throws Exception {
        boolean exists = minioClient.bucketExists(BucketExistsArgs.builder().bucket(bucketName).build());
        if (!exists) {
            minioClient.makeBucket(MakeBucketArgs.builder().bucket(bucketName).build());
        }
    }

    private String resolveExtension(MultipartFile file) {
        String filename = file.getOriginalFilename();
        if (filename != null) {
            String lower = filename.trim().toLowerCase(Locale.ROOT);
            if (lower.endsWith(".jpg") || lower.endsWith(".jpeg") || lower.endsWith(".jfif")) {
                return "jpg";
            }
            if (lower.endsWith(".png")) {
                return "png";
            }
            if (lower.endsWith(".webp")) {
                return "webp";
            }
        }

        String contentType = file.getContentType();
        if (contentType != null) {
            String lowerType = contentType.trim().toLowerCase(Locale.ROOT);
            if (lowerType.startsWith("image/jpeg") || lowerType.startsWith("image/jpg") || lowerType.startsWith("image/pjpeg")) {
                return "jpg";
            }
            if (lowerType.startsWith("image/png")) {
                return "png";
            }
            if (lowerType.startsWith("image/webp")) {
                return "webp";
            }
        }

        log.warn("不支持的图片格式, contentType={}, filename={}", file.getContentType(), filename);
        throw new BizException(400, "仅支持 JPG、PNG、WebP 格式图片");
    }

    private byte[] compressImage(MultipartFile file, String ext) {
        try {
            byte[] rawBytes = file.getBytes();
            if ("webp".equals(ext)) {
                return rawBytes;
            }

            BufferedImage probe = ImageIO.read(new ByteArrayInputStream(rawBytes));
            if (probe == null || probe.getWidth() <= 0 || probe.getHeight() <= 0) {
                throw new BizException(400, "无法解析该图片文件");
            }

            ByteArrayOutputStream output = new ByteArrayOutputStream();
            Thumbnails.Builder<? extends InputStream> builder = Thumbnails.of(new ByteArrayInputStream(rawBytes));
            if (Math.max(probe.getWidth(), probe.getHeight()) > MAX_EDGE) {
                builder.size(MAX_EDGE, MAX_EDGE);
            } else {
                builder.scale(1.0);
            }

            if ("png".equals(ext)) {
                builder.outputFormat("png").toOutputStream(output);
            } else {
                builder.outputFormat("jpg").outputQuality(JPEG_QUALITY).toOutputStream(output);
            }
            return output.toByteArray();
        } catch (BizException e) {
            throw e;
        } catch (IOException e) {
            log.warn("图片压缩失败, ext={}", ext, e);
            throw new BizException(400, "无法解析该图片文件");
        }
    }

    private MediaType resolveMediaTypeByExt(String extOrObjectName) {
        String lower = extOrObjectName == null ? "" : extOrObjectName.toLowerCase(Locale.ROOT);
        if (lower.endsWith("png")) {
            return MediaType.IMAGE_PNG;
        }
        if (lower.endsWith("webp")) {
            return MEDIA_TYPE_WEBP;
        }
        return MediaType.IMAGE_JPEG;
    }

    private void removeObjectQuietly(String objectName) {
        try {
            minioClient.removeObject(RemoveObjectArgs.builder().bucket(bucket).object(objectName).build());
        } catch (Exception ex) {
            log.warn("回滚清理 MinIO 对象失败, objectName={}", objectName, ex);
        }
    }

    /**
     * 图片流读取结果包装。
     */
    public record ImageStreamResult(String id, MediaType mediaType, InputStream stream) {
    }
}
