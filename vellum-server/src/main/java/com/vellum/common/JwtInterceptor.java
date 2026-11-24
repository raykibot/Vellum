package com.vellum.common;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.vellum.service.AuthService;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Component;
import org.springframework.web.servlet.HandlerInterceptor;

import java.io.IOException;
import java.nio.charset.StandardCharsets;

/**
 * 轻量 JWT 鉴权拦截器（Token 有效期 7 天）。
 */
@Component
@RequiredArgsConstructor
@Slf4j
public class JwtInterceptor implements HandlerInterceptor {

    private final AuthService authService;
    private final ObjectMapper objectMapper;

    @Override
    public boolean preHandle(HttpServletRequest request, HttpServletResponse response, Object handler) throws IOException {
        if ("OPTIONS".equalsIgnoreCase(request.getMethod())) {
            return true;
        }

        // 1. 提取 token（常规接口走 Authorization Bearer，<img> 图片请求支持 ?token=）
        String authHeader = request.getHeader(HttpHeaders.AUTHORIZATION);
        String token = (authHeader != null && authHeader.startsWith("Bearer "))
                ? authHeader.substring(7).trim()
                : request.getParameter("token");

        // 2. 判空
        if (token == null || token.isBlank()) {
            writeUnauthorized(response, "未登录或登录已过期");
            return false;
        }

        // 3. 校验并返回结果
        try {
            authService.parseToken(token);
            return true;
        } catch (BizException e) {
            log.warn("鉴权失败, uri={}, message={}", request.getRequestURI(), e.getMessage());
            writeUnauthorized(response, e.getMessage());
            return false;
        }
    }

    private void writeUnauthorized(HttpServletResponse response, String message) throws IOException {
        response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
        response.setCharacterEncoding(StandardCharsets.UTF_8.name());
        response.setContentType(MediaType.APPLICATION_JSON_VALUE + ";charset=UTF-8");
        response.getWriter().write(objectMapper.writeValueAsString(Result.fail(401, message)));
    }
}
