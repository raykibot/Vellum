package com.vellum.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

import java.time.OffsetDateTime;

/**
 * 发布动态 / 长文请求参数。
 */
public record CreatePostRequest(
        @Size(max = 200, message = "标题长度不能超过200个字符") String title,
        String type,
        @NotBlank(message = "正文内容不能为空") String content,
        @Size(max = 64, message = "城市名称长度不能超过64个字符") String locationCity,
        OffsetDateTime recordTime
) {
}
