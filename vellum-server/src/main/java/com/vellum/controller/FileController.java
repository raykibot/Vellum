package com.vellum.controller;

import com.vellum.common.BizException;
import com.vellum.common.Result;
import com.vellum.dto.UploadFileResponse;
import com.vellum.entity.PostImage;
import com.vellum.service.FileService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.core.io.InputStreamResource;
import org.springframework.http.CacheControl;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

import java.util.concurrent.TimeUnit;

/**
 * 图片上传与流式代理读取接口（基于私有 MinIO Bucket）。
 */
@RestController
@RequestMapping("/api/v1/files")
@RequiredArgsConstructor
@Slf4j
public class FileController {

    private static final CacheControl IMMUTABLE_CACHE = CacheControl.maxAge(365, TimeUnit.DAYS)
            .cachePrivate()
            .immutable();

    private final FileService fileService;

    @PostMapping(value = "/upload", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public Result<UploadFileResponse> upload(@RequestParam("file") MultipartFile file) {
        log.info("上传图片");
        try {
            return Result.ok(fileService.upload(file));
        } catch (BizException e) {
            log.warn("上传图片失败, code={}, message={}", e.getCode(), e.getMessage(), e);
            return Result.fail(e.getCode(), e.getMessage());
        } catch (Exception e) {
            log.error("上传图片异常", e);
            return Result.fail(500, "上传失败");
        }
    }

    @GetMapping("/{id}")
    public ResponseEntity<InputStreamResource> view(
            @PathVariable String id,
            @RequestHeader(value = HttpHeaders.IF_NONE_MATCH, required = false) String ifNoneMatch) {
        try {
            PostImage meta = fileService.getActiveImageMeta(id);
            if (isEtagMatch(ifNoneMatch, meta.getId())) {
                return ResponseEntity.status(HttpStatus.NOT_MODIFIED)
                        .eTag(meta.getId())
                        .cacheControl(IMMUTABLE_CACHE)
                        .build();
            }

            FileService.ImageStreamResult streamResult = fileService.openImageStream(meta);
            return ResponseEntity.ok()
                    .contentType(streamResult.mediaType())
                    .eTag(streamResult.id())
                    .cacheControl(IMMUTABLE_CACHE)
                    .body(new InputStreamResource(streamResult.stream()));
        } catch (BizException e) {
            if (e.getCode() == 400) {
                return ResponseEntity.badRequest().build();
            }
            if (e.getCode() == 404) {
                return ResponseEntity.notFound().build();
            }
            log.warn("读取图片失败, id={}, code={}, message={}", id, e.getCode(), e.getMessage());
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        } catch (Exception e) {
            log.error("读取图片异常, id={}", id, e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    private boolean isEtagMatch(String ifNoneMatch, String id) {
        if (ifNoneMatch == null || ifNoneMatch.isBlank()) {
            return false;
        }
        String quoted = "\"" + id + "\"";
        for (String candidate : ifNoneMatch.split(",")) {
            String trimmed = candidate.trim();
            if ("*".equals(trimmed)
                    || quoted.equals(trimmed)
                    || id.equals(trimmed)
                    || ("W/" + quoted).equals(trimmed)) {
                return true;
            }
        }
        return false;
    }
}
