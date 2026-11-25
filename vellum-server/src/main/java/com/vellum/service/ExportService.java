package com.vellum.service;

import com.vellum.common.BizException;
import com.vellum.entity.Post;
import com.vellum.entity.PostImage;
import com.vellum.mapper.PostImageMapper;
import com.vellum.mapper.PostMapper;
import io.minio.GetObjectArgs;
import io.minio.MinioClient;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.nio.charset.StandardCharsets;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.time.ZonedDateTime;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.zip.Deflater;
import java.util.zip.ZipEntry;
import java.util.zip.ZipOutputStream;

/**
 * AI 导出服务（按时间段整理为汇总 Markdown 与含图 ZIP 包）。
 */
@Service
@Slf4j
public class ExportService {

    private static final ZoneId CHINA_ZONE = ZoneId.of("Asia/Shanghai");
    private static final DateTimeFormatter COMPACT_DATE_FORMAT = DateTimeFormatter.ofPattern("yyyyMMdd");
    private static final DateTimeFormatter DATETIME_FORMAT = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm");
    private static final DateTimeFormatter IMAGE_TIME_FORMAT = DateTimeFormatter.ofPattern("yyyyMMdd-HHmm");
    private static final String TYPE_ALL = "ALL";
    private static final String TYPE_MOMENT = "MOMENT";
    private static final String TYPE_ARTICLE = "ARTICLE";

    private final PostMapper postMapper;
    private final PostImageMapper postImageMapper;
    private final MinioClient minioClient;
    private final String bucket;

    public ExportService(
            PostMapper postMapper,
            PostImageMapper postImageMapper,
            MinioClient minioClient,
            @Value("${vellum.minio.bucket:vellum}") String bucket) {
        this.postMapper = postMapper;
        this.postImageMapper = postImageMapper;
        this.minioClient = minioClient;
        this.bucket = bucket;
    }

    public record ImageEntry(String zipPath, String objectName, String imageId) {
    }

    public record ExportPlan(String zipFilename, String markdown, List<ImageEntry> images) {
    }

    /**
     * 校验导出条件、查询记录与图片元数据并生成导出计划（写出 ZIP 流前完成所有业务校验）。
     */
    public ExportPlan prepareExport(LocalDate startDate, LocalDate endDate, String rawType) {
        if (startDate != null && endDate != null && startDate.isAfter(endDate)) {
            throw new BizException(400, "开始日期不能晚于结束日期");
        }
        String filterType = resolveFilterType(rawType);

        OffsetDateTime startTime = startDate != null
                ? startDate.atStartOfDay(CHINA_ZONE).toOffsetDateTime()
                : null;
        OffsetDateTime endTimeExclusive = endDate != null
                ? endDate.plusDays(1).atStartOfDay(CHINA_ZONE).toOffsetDateTime()
                : null;

        List<Post> posts = postMapper.selectForExport(filterType, startTime, endTimeExclusive);
        if (posts == null || posts.isEmpty()) {
            throw new BizException(404, "所选时间范围内暂无可导出的记录");
        }

        Map<String, List<PostImage>> imagesByPostId = loadImagesByPostIds(posts);
        List<ImageEntry> imageEntries = new ArrayList<>();
        String markdown = buildJournalMarkdown(posts, imagesByPostId, imageEntries, startDate, endDate);
        String zipFilename = buildZipFilename(startDate, endDate);

        return new ExportPlan(zipFilename, markdown, imageEntries);
    }

    /**
     * 将汇总 Markdown 与 MinIO 关联图片流式写入 ZIP 输出流（单图缺失时跳过并记录告警）。
     */
    public void writeZip(ExportPlan plan, OutputStream outputStream) throws IOException {
        ZipOutputStream zos = new ZipOutputStream(outputStream, StandardCharsets.UTF_8);
        zos.setLevel(Deflater.BEST_SPEED);

        zos.putNextEntry(new ZipEntry("journal.md"));
        zos.write(plan.markdown().getBytes(StandardCharsets.UTF_8));
        zos.closeEntry();

        for (ImageEntry image : plan.images()) {
            try (InputStream in = minioClient.getObject(
                    GetObjectArgs.builder()
                            .bucket(bucket)
                            .object(image.objectName())
                            .build())) {
                zos.putNextEntry(new ZipEntry(image.zipPath()));
                in.transferTo(zos);
                zos.closeEntry();
            } catch (Exception e) {
                log.warn("导出跳过缺失图片, imageId={}, objectName={}", image.imageId(), image.objectName(), e);
            }
        }

        zos.finish();
        zos.flush();
    }

    private String resolveFilterType(String rawType) {
        if (rawType == null || rawType.isBlank()) {
            return null;
        }
        String upper = rawType.trim().toUpperCase(Locale.ROOT);
        if (TYPE_ALL.equals(upper)) {
            return null;
        }
        if (TYPE_MOMENT.equals(upper) || TYPE_ARTICLE.equals(upper)) {
            return upper;
        }
        throw new BizException(400, "不支持的筛选类型，仅允许 ALL、MOMENT 或 ARTICLE");
    }

    private Map<String, List<PostImage>> loadImagesByPostIds(List<Post> posts) {
        List<String> postIds = posts.stream().map(Post::getId).toList();
        List<PostImage> images = postImageMapper.selectByPostIds(postIds);
        Map<String, List<PostImage>> grouped = new HashMap<>();
        if (images != null) {
            for (PostImage image : images) {
                grouped.computeIfAbsent(image.getPostId(), k -> new ArrayList<>()).add(image);
            }
        }
        return grouped;
    }

    private String buildJournalMarkdown(
            List<Post> posts,
            Map<String, List<PostImage>> imagesByPostId,
            List<ImageEntry> imageEntries,
            LocalDate startDate,
            LocalDate endDate) {
        long momentCount = posts.stream().filter(p -> TYPE_MOMENT.equals(p.getType())).count();
        long articleCount = posts.stream().filter(p -> TYPE_ARTICLE.equals(p.getType())).count();

        StringBuilder sb = new StringBuilder();
        sb.append("# Vellum 记录导出\n\n");
        sb.append("- 时间范围：").append(formatRangeLabel(startDate, endDate)).append('\n');
        sb.append("- 记录统计：共 ").append(posts.size()).append(" 条（动态 ")
                .append(momentCount).append(" 条，长文 ").append(articleCount).append(" 篇）\n");
        sb.append("- 导出时间：").append(DATETIME_FORMAT.format(OffsetDateTime.now(CHINA_ZONE))).append('\n');

        for (Post post : posts) {
            ZonedDateTime recordChinaTime = post.getRecordTime() != null
                    ? post.getRecordTime().atZoneSameInstant(CHINA_ZONE)
                    : ZonedDateTime.now(CHINA_ZONE);
            boolean isArticle = TYPE_ARTICLE.equals(post.getType());

            sb.append("\n---\n\n");
            sb.append("## ").append(DATETIME_FORMAT.format(recordChinaTime))
                    .append(" · ").append(isArticle ? "长文" : "动态");
            if (post.getLocationCity() != null && !post.getLocationCity().isBlank()) {
                sb.append(" · ").append(post.getLocationCity().trim());
            }
            sb.append('\n');

            if (isArticle && post.getTitle() != null && !post.getTitle().isBlank()) {
                sb.append("### ").append(post.getTitle().trim()).append('\n');
            }

            String rawBody = post.getContent() == null ? "" : post.getContent();
            String body = isArticle
                    ? PostService.stripDuplicateLeadingHeading(rawBody, post.getTitle()).trim()
                    : rawBody.trim();
            if (!body.isEmpty()) {
                sb.append('\n').append(body).append('\n');
            }

            List<PostImage> postImages = imagesByPostId.getOrDefault(post.getId(), List.of());
            if (!postImages.isEmpty()) {
                sb.append('\n');
                for (int i = 0; i < postImages.size(); i++) {
                    PostImage img = postImages.get(i);
                    String filename = buildImageFilename(recordChinaTime, i + 1, img);
                    String zipPath = "images/" + filename;
                    imageEntries.add(new ImageEntry(zipPath, img.getObjectName(), img.getId()));
                    sb.append("![](").append(zipPath).append(")\n");
                }
            }
        }

        return sb.toString();
    }

    private String formatRangeLabel(LocalDate startDate, LocalDate endDate) {
        if (startDate != null && endDate != null) {
            return startDate + " ~ " + endDate;
        }
        if (startDate != null) {
            return startDate + " 至今";
        }
        if (endDate != null) {
            return "截至 " + endDate;
        }
        return "全部时间";
    }

    private String buildImageFilename(ZonedDateTime recordTime, int index, PostImage image) {
        String id = image.getId() != null ? image.getId() : "";
        String shortId = id.length() >= 8 ? id.substring(0, 8) : id;
        String ext = extractExtension(image.getObjectName());
        return IMAGE_TIME_FORMAT.format(recordTime) + "-" + index + "-" + shortId + "." + ext;
    }

    private String extractExtension(String objectName) {
        if (objectName == null) {
            return "jpg";
        }
        int dotIdx = objectName.lastIndexOf('.');
        if (dotIdx < 0 || dotIdx == objectName.length() - 1) {
            return "jpg";
        }
        String ext = objectName.substring(dotIdx + 1).trim().toLowerCase(Locale.ROOT);
        return ext.isEmpty() ? "jpg" : ext;
    }

    private String buildZipFilename(LocalDate startDate, LocalDate endDate) {
        if (startDate != null && endDate != null) {
            return "vellum-export-" + COMPACT_DATE_FORMAT.format(startDate)
                    + "-" + COMPACT_DATE_FORMAT.format(endDate) + ".zip";
        }
        if (startDate != null) {
            return "vellum-export-from-" + COMPACT_DATE_FORMAT.format(startDate) + ".zip";
        }
        if (endDate != null) {
            return "vellum-export-until-" + COMPACT_DATE_FORMAT.format(endDate) + ".zip";
        }
        return "vellum-export-all-" + COMPACT_DATE_FORMAT.format(LocalDate.now(CHINA_ZONE)) + ".zip";
    }
}
