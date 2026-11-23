package com.vellum.service;

import com.vellum.common.BizException;
import com.vellum.dto.LoginRequest;
import com.vellum.dto.LoginResponse;
import com.vellum.entity.SysUser;
import com.vellum.mapper.SysUserMapper;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.stereotype.Service;

import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.Date;

/**
 * 登录与账号服务。
 */
@Service
@RequiredArgsConstructor
public class AuthService {

    private final SysUserMapper sysUserMapper;
    private final BCryptPasswordEncoder passwordEncoder = new BCryptPasswordEncoder();

    @Value("${vellum.jwt.secret}")
    private String jwtSecret;

    @Value("${vellum.jwt.expire-days:7}")
    private long expireDays;

    /**
     * 校验账号密码并签发 7 天有效期 JWT Token。
     */
    public LoginResponse login(LoginRequest request) {
        SysUser user = sysUserMapper.selectByUsername(request.username().trim());
        if (user == null || !passwordEncoder.matches(request.password(), user.getPasswordHash())) {
            throw new BizException(401, "用户名或密码错误");
        }

        OffsetDateTime now = OffsetDateTime.now(ZoneOffset.UTC);
        OffsetDateTime expiresAt = now.plusDays(expireDays);

        SecretKey key = Keys.hmacShaKeyFor(jwtSecret.getBytes(StandardCharsets.UTF_8));
        String token = Jwts.builder()
                .subject(user.getId())
                .claim("username", user.getUsername())
                .issuedAt(Date.from(now.toInstant()))
                .expiration(Date.from(expiresAt.toInstant()))
                .signWith(key)
                .compact();

        return new LoginResponse(token, expiresAt);
    }

    // TODO: 后续补充 changePassword 方法
}
