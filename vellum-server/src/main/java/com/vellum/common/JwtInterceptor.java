package com.vellum.common;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.stereotype.Component;
import org.springframework.web.servlet.HandlerInterceptor;

/**
 * 轻量 JWT 鉴权拦截器骨架（Token 有效期 7 天）。
 */
@Component
public class JwtInterceptor implements HandlerInterceptor {

    @Override
    public boolean preHandle(HttpServletRequest request, HttpServletResponse response, Object handler) {
        // TODO: 放行 OPTIONS 预检请求，校验 Authorization Bearer JWT 合法性与 7 天有效期
        return true;
    }
}
