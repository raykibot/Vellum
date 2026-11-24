package com.vellum.dto;

/**
 * 图片上传成功响应结果。
 */
public record UploadFileResponse(
        String id,
        String url
) {
}
