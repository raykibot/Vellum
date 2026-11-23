package com.vellum.controller;

import com.vellum.common.BizException;
import com.vellum.common.Result;
import com.vellum.dto.LoginRequest;
import com.vellum.dto.LoginResponse;
import com.vellum.service.AuthService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * 登录与改密接口。
 */
@RestController
@RequestMapping("/api/v1/auth")
@RequiredArgsConstructor
@Slf4j
public class AuthController {

    private final AuthService authService;

    @PostMapping("/login")
    public Result<LoginResponse> login(@Valid @RequestBody LoginRequest request) {
        log.info("登录");
        try {
            return Result.ok(authService.login(request));
        } catch (BizException e) {
            log.warn("登录失败, username={}, code={}, message={}",
                    request.username(), e.getCode(), e.getMessage(), e);
            return Result.fail(e.getCode(), e.getMessage());
        } catch (Exception e) {
            log.error("登录处理异常, username={}", request.username(), e);
            return Result.fail(1, "fail");
        }
    }

    @PutMapping("/password")
    public Result<Void> changePassword() {
        // TODO: 校验旧密码并更新密码
        throw new BizException(501, "接口尚未实现");
    }
}
