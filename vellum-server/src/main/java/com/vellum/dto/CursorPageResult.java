package com.vellum.dto;

import java.time.OffsetDateTime;
import java.util.List;

/**
 * 游标分页响应结构。
 */
public record CursorPageResult<T>(
        int size,
        boolean hasMore,
        OffsetDateTime nextCursorTime,
        String nextCursorId,
        List<T> items
) {
}
