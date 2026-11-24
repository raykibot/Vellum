package com.vellum;

import com.vellum.common.BizException;
import com.vellum.common.GlobalExceptionHandler;
import com.vellum.controller.FileController;
import com.vellum.dto.UploadFileResponse;
import com.vellum.entity.PostImage;
import com.vellum.mapper.PostImageMapper;
import com.vellum.service.FileService;
import io.minio.BucketExistsArgs;
import io.minio.GetObjectArgs;
import io.minio.GetObjectResponse;
import io.minio.MakeBucketArgs;
import io.minio.MinioClient;
import io.minio.PutObjectArgs;
import io.minio.RemoveObjectArgs;
import okhttp3.Headers;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;

import javax.imageio.ImageIO;
import java.awt.Color;
import java.awt.Graphics2D;
import java.awt.image.BufferedImage;
import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.nio.charset.StandardCharsets;

import static org.hamcrest.Matchers.containsString;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.multipart;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * MinIO 图片压缩上传与代理读取单元测试。
 */
@ExtendWith(MockitoExtension.class)
class FileServiceTest {

    @Mock
    private MinioClient minioClient;

    @Mock
    private PostImageMapper postImageMapper;

    private FileService fileService;

    @BeforeEach
    void setUp() {
        fileService = new FileService(minioClient, postImageMapper, "vellum");
    }

    @Test
    void uploadShouldCompressLargeJpegAndCreateBucketWhenMissing() throws Exception {
        byte[] rawJpeg = createImageBytes(2400, 1200, BufferedImage.TYPE_INT_RGB, "jpg");
        MockMultipartFile file = new MockMultipartFile("file", "sunset.jpg", MediaType.IMAGE_JPEG_VALUE, rawJpeg);

        when(minioClient.bucketExists(any(BucketExistsArgs.class))).thenReturn(false);
        when(postImageMapper.insertImage(any(PostImage.class))).thenReturn(1);

        UploadFileResponse response = fileService.upload(file);

        assertEquals("/api/v1/files/" + response.id(), response.url());
        verify(minioClient).makeBucket(any(MakeBucketArgs.class));

        ArgumentCaptor<PutObjectArgs> putCaptor = ArgumentCaptor.forClass(PutObjectArgs.class);
        verify(minioClient).putObject(putCaptor.capture());
        assertEquals("vellum", putCaptor.getValue().bucket());
        assertEquals(MediaType.IMAGE_JPEG_VALUE, putCaptor.getValue().contentType());
        assertTrue(putCaptor.getValue().object().matches("^\\d{4}/\\d{2}/" + response.id() + "\\.jpg$"));

        ArgumentCaptor<PostImage> dbCaptor = ArgumentCaptor.forClass(PostImage.class);
        verify(postImageMapper).insertImage(dbCaptor.capture());
        assertNull(dbCaptor.getValue().getPostId());
        assertFalse(dbCaptor.getValue().getDeleted());
        assertEquals(0, dbCaptor.getValue().getSortOrder());
    }

    @Test
    void uploadShouldPreserveAlphaPng() throws Exception {
        byte[] rawPng = createImageBytes(300, 200, BufferedImage.TYPE_INT_ARGB, "png");
        MockMultipartFile file = new MockMultipartFile("file", "sticker.png", MediaType.IMAGE_PNG_VALUE, rawPng);

        when(minioClient.bucketExists(any(BucketExistsArgs.class))).thenReturn(true);
        when(postImageMapper.insertImage(any(PostImage.class))).thenReturn(1);

        fileService.upload(file);

        ArgumentCaptor<PutObjectArgs> putCaptor = ArgumentCaptor.forClass(PutObjectArgs.class);
        verify(minioClient).putObject(putCaptor.capture());
        assertEquals(MediaType.IMAGE_PNG_VALUE, putCaptor.getValue().contentType());
        assertTrue(putCaptor.getValue().object().endsWith(".png"));
    }

    @Test
    void uploadShouldAcceptValidWebp() throws Exception {
        byte[] webpBytes = "webp-payload".getBytes(StandardCharsets.US_ASCII);
        MockMultipartFile file = new MockMultipartFile("file", "photo.webp", "image/webp", webpBytes);

        when(minioClient.bucketExists(any(BucketExistsArgs.class))).thenReturn(true);
        when(postImageMapper.insertImage(any(PostImage.class))).thenReturn(1);

        UploadFileResponse response = fileService.upload(file);

        assertTrue(response.url().startsWith("/api/v1/files/"));
        ArgumentCaptor<PutObjectArgs> putCaptor = ArgumentCaptor.forClass(PutObjectArgs.class);
        verify(minioClient).putObject(putCaptor.capture());
        assertEquals("image/webp", putCaptor.getValue().contentType());
        assertTrue(putCaptor.getValue().object().endsWith(".webp"));
    }

    @Test
    void uploadShouldAcceptJfifExtensionAndLegacyJpegMime() throws Exception {
        byte[] rawJpeg = createImageBytes(120, 80, BufferedImage.TYPE_INT_RGB, "jpg");
        MockMultipartFile file = new MockMultipartFile("file", "wallpaper.jfif", "image/pjpeg", rawJpeg);

        when(minioClient.bucketExists(any(BucketExistsArgs.class))).thenReturn(true);
        when(postImageMapper.insertImage(any(PostImage.class))).thenReturn(1);

        UploadFileResponse response = fileService.upload(file);

        assertEquals("/api/v1/files/" + response.id(), response.url());
        ArgumentCaptor<PutObjectArgs> putCaptor = ArgumentCaptor.forClass(PutObjectArgs.class);
        verify(minioClient).putObject(putCaptor.capture());
        assertEquals(MediaType.IMAGE_JPEG_VALUE, putCaptor.getValue().contentType());
        assertTrue(putCaptor.getValue().object().endsWith(".jpg"));
    }

    @Test
    void uploadShouldRejectEmptyUnsupportedOrCorruptFiles() {
        MockMultipartFile empty = new MockMultipartFile("file", "a.jpg", MediaType.IMAGE_JPEG_VALUE, new byte[0]);
        assertEquals(400, assertThrows(BizException.class, () -> fileService.upload(empty)).getCode());

        MockMultipartFile text = new MockMultipartFile("file", "note.txt", MediaType.TEXT_PLAIN_VALUE, "hi".getBytes(StandardCharsets.UTF_8));
        assertEquals(400, assertThrows(BizException.class, () -> fileService.upload(text)).getCode());

        MockMultipartFile corruptJpg = new MockMultipartFile("file", "bad.jpg", MediaType.IMAGE_JPEG_VALUE, "not-an-image".getBytes(StandardCharsets.UTF_8));
        assertEquals(400, assertThrows(BizException.class, () -> fileService.upload(corruptJpg)).getCode());
    }

    @Test
    void uploadShouldCompensateMinioWhenDatabaseInsertFails() throws Exception {
        byte[] rawJpeg = createImageBytes(120, 80, BufferedImage.TYPE_INT_RGB, "jpg");
        MockMultipartFile file = new MockMultipartFile("file", "photo.jpg", MediaType.IMAGE_JPEG_VALUE, rawJpeg);

        when(minioClient.bucketExists(any(BucketExistsArgs.class))).thenReturn(true);
        when(postImageMapper.insertImage(any(PostImage.class))).thenThrow(new RuntimeException("DB error"));

        assertThrows(RuntimeException.class, () -> fileService.upload(file));

        verify(minioClient).putObject(any(PutObjectArgs.class));
        verify(minioClient).removeObject(any(RemoveObjectArgs.class));
    }

    @Test
    void controllerUploadAndViewShouldHandleStreamEtagAnd404() throws Exception {
        byte[] jpegBytes = createImageBytes(64, 64, BufferedImage.TYPE_INT_RGB, "jpg");
        PostImage meta = new PostImage();
        meta.setId("img-1");
        meta.setObjectName("2026/11/img-1.jpg");
        meta.setDeleted(false);

        when(minioClient.bucketExists(any(BucketExistsArgs.class))).thenReturn(true);
        when(postImageMapper.insertImage(any(PostImage.class))).thenReturn(1);
        when(postImageMapper.selectActiveById("img-1")).thenReturn(meta);
        when(postImageMapper.selectActiveById("missing")).thenReturn(null);
        when(minioClient.getObject(any(GetObjectArgs.class)))
                .thenReturn(new GetObjectResponse(
                        new Headers.Builder().build(),
                        "vellum",
                        null,
                        "2026/11/img-1.jpg",
                        new ByteArrayInputStream(jpegBytes)
                ));

        MockMvc mockMvc = MockMvcBuilders
                .standaloneSetup(new FileController(fileService))
                .setControllerAdvice(new GlobalExceptionHandler())
                .build();

        mockMvc.perform(multipart("/api/v1/files/upload")
                        .file(new MockMultipartFile("file", "pic.jpg", MediaType.IMAGE_JPEG_VALUE, jpegBytes)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(0))
                .andExpect(jsonPath("$.data.id").isNotEmpty())
                .andExpect(jsonPath("$.data.url").isNotEmpty());

        mockMvc.perform(get("/api/v1/files/img-1")
                        .header(HttpHeaders.IF_NONE_MATCH, "\"img-1\""))
                .andExpect(status().isNotModified())
                .andExpect(header().string(HttpHeaders.ETAG, "\"img-1\""))
                .andExpect(header().string(HttpHeaders.CACHE_CONTROL, containsString("immutable")));
        verify(minioClient, never()).getObject(any(GetObjectArgs.class));

        mockMvc.perform(get("/api/v1/files/img-1"))
                .andExpect(status().isOk())
                .andExpect(header().string(HttpHeaders.ETAG, "\"img-1\""))
                .andExpect(header().string(HttpHeaders.CACHE_CONTROL, containsString("immutable")))
                .andExpect(content().contentType(MediaType.IMAGE_JPEG))
                .andExpect(content().bytes(jpegBytes));

        mockMvc.perform(get("/api/v1/files/missing"))
                .andExpect(status().isNotFound());
    }

    private byte[] createImageBytes(int width, int height, int imageType, String format) throws IOException {
        BufferedImage img = new BufferedImage(width, height, imageType);
        Graphics2D g = img.createGraphics();
        g.setColor(imageType == BufferedImage.TYPE_INT_ARGB ? new Color(255, 120, 80, 128) : Color.DARK_GRAY);
        g.fillRect(0, 0, width, height);
        g.dispose();

        ByteArrayOutputStream out = new ByteArrayOutputStream();
        ImageIO.write(img, format, out);
        return out.toByteArray();
    }
}
