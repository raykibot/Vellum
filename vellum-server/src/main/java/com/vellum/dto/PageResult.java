package com.vellum.dto;

import java.util.List;

/**
 * 通用分页响应结构。
 */
public record PageResult<T>(
        int page,
        int size,
        long total,
        List<T> items
) {
}
