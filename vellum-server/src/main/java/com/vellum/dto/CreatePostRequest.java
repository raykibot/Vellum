package com.vellum.dto;

import jakarta.validation.constraints.Size;

import java.time.OffsetDateTime;
import java.util.List;

/**
 * 发布动态 / 长文请求参数（支持纯图动态，最多 9 张）。
 */
public record CreatePostRequest(
        @Size(max = 200, message = "标题长度不能超过200个字符") String title,
        String type,
        String content,
        @Size(max = 64, message = "城市名称长度不能超过64个字符") String locationCity,
        OffsetDateTime recordTime,
        @Size(max = 9, message = "单条记录最多上传9张图片") List<String> imageIds
) {
    public CreatePostRequest(
            String title,
            String type,
            String content,
            String locationCity,
            OffsetDateTime recordTime) {
        this(title, type, content, locationCity, recordTime, null);
    }
}
