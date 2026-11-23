package com.vellum.dto;

import java.time.OffsetDateTime;

/**
 * 登录成功响应结果。
 */
public record LoginResponse(
        String token,
        OffsetDateTime expiresAt
) {
}
