package com.vellum.dto;

import java.time.OffsetDateTime;
import java.util.List;

/**
 * 时间线单条记录响应对象。
 */
public record PostItem(
        String id,
        String type,
        String title,
        String content,
        String locationCity,
        OffsetDateTime recordTime,
        OffsetDateTime createdAt,
        OffsetDateTime updatedAt,
        List<String> images,
        boolean contentTruncated
) {
}
