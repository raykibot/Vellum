package com.vellum;

import com.vellum.common.BizException;
import com.vellum.common.GlobalExceptionHandler;
import com.vellum.controller.AuthController;
import com.vellum.dto.LoginRequest;
import com.vellum.dto.LoginResponse;
import com.vellum.entity.SysUser;
import com.vellum.mapper.SysUserMapper;
import com.vellum.service.AuthService;
import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.MediaType;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.test.util.ReflectionTestUtils;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;

import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Duration;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.Date;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * 登录鉴权核心逻辑单元测试。
 */
@ExtendWith(MockitoExtension.class)
class AuthServiceTest {

    private static final String TEST_JWT_SECRET = "change-me-to-a-256-bit-secret-key-for-vellum-dev-only";
    private static final String DEFAULT_USER_ID = "00000000-0000-0000-0000-000000000001";

    @Mock
    private SysUserMapper sysUserMapper;

    private AuthService authService;
    private final BCryptPasswordEncoder passwordEncoder = new BCryptPasswordEncoder();

    @BeforeEach
    void setUp() {
        authService = new AuthService(sysUserMapper);
        ReflectionTestUtils.setField(authService, "jwtSecret", TEST_JWT_SECRET);
        ReflectionTestUtils.setField(authService, "expireDays", 7L);
    }

    @Test
    void loginSuccessShouldReturnSevenDayJwt() {
        SysUser user = buildUser("Luojiakeng", passwordEncoder.encode("690501"));
        when(sysUserMapper.selectByUsername("Luojiakeng")).thenReturn(user);

        LoginResponse response = authService.login(new LoginRequest(" Luojiakeng ", "690501"));

        assertNotNull(response.token());
        assertNotNull(response.expiresAt());

        SecretKey key = Keys.hmacShaKeyFor(TEST_JWT_SECRET.getBytes(StandardCharsets.UTF_8));
        Claims claims = Jwts.parser()
                .verifyWith(key)
                .build()
                .parseSignedClaims(response.token())
                .getPayload();

        assertEquals(DEFAULT_USER_ID, claims.getSubject());
        assertEquals("Luojiakeng", claims.get("username", String.class));
        assertEquals(7L, Duration.between(claims.getIssuedAt().toInstant(), claims.getExpiration().toInstant()).toDays());
    }

    @Test
    void loginShouldFailWhenUserNotFound() {
        when(sysUserMapper.selectByUsername("unknown")).thenReturn(null);

        BizException ex = assertThrows(BizException.class,
                () -> authService.login(new LoginRequest("unknown", "690501")));
        assertEquals(401, ex.getCode());
    }

    @Test
    void loginShouldFailWhenPasswordWrong() {
        SysUser user = buildUser("Luojiakeng", passwordEncoder.encode("690501"));
        when(sysUserMapper.selectByUsername("Luojiakeng")).thenReturn(user);

        BizException ex = assertThrows(BizException.class,
                () -> authService.login(new LoginRequest("Luojiakeng", "wrong-pwd")));
        assertEquals(401, ex.getCode());
    }

    @Test
    void schemaDefaultUserHashShouldMatch690501() throws Exception {
        Path schemaPath = Path.of("src/main/resources/sql/schema.sql");
        if (!Files.exists(schemaPath)) {
            schemaPath = Path.of("vellum-server/src/main/resources/sql/schema.sql");
        }
        String sql = Files.readString(schemaPath);
        Matcher matcher = Pattern.compile("'Luojiakeng',\\s*'(\\$2[aby]\\$\\d+\\$[^']+)'").matcher(sql);
        assertTrue(matcher.find(), "schema.sql 中未找到 Luojiakeng 的 BCrypt 密文");
        assertTrue(passwordEncoder.matches("690501", matcher.group(1)));
    }

    @Test
    void controllerLoginShouldValidateAndReturnToken() throws Exception {
        SysUser user = buildUser("Luojiakeng", passwordEncoder.encode("690501"));
        when(sysUserMapper.selectByUsername("Luojiakeng")).thenReturn(user);

        MockMvc mockMvc = MockMvcBuilders
                .standaloneSetup(new AuthController(authService))
                .setControllerAdvice(new GlobalExceptionHandler())
                .build();

        mockMvc.perform(post("/api/v1/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"username\":\"Luojiakeng\",\"password\":\"690501\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(0))
                .andExpect(jsonPath("$.data.token").isNotEmpty());

        mockMvc.perform(post("/api/v1/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"username\":\"\",\"password\":\"\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(400));
    }

    @Test
    void parseTokenShouldVerifyValidRejectExpiredAndWrongSecret() {
        SysUser user = buildUser("Luojiakeng", passwordEncoder.encode("690501"));
        when(sysUserMapper.selectByUsername("Luojiakeng")).thenReturn(user);

        LoginResponse response = authService.login(new LoginRequest("Luojiakeng", "690501"));
        Claims claims = authService.parseToken(response.token());
        assertEquals(DEFAULT_USER_ID, claims.getSubject());
        assertEquals("Luojiakeng", claims.get("username", String.class));

        BizException blankEx = assertThrows(BizException.class, () -> authService.parseToken(" "));
        assertEquals(401, blankEx.getCode());

        SecretKey validKey = Keys.hmacShaKeyFor(TEST_JWT_SECRET.getBytes(StandardCharsets.UTF_8));
        String expiredToken = Jwts.builder()
                .subject(DEFAULT_USER_ID)
                .issuedAt(Date.from(Instant.now().minus(8, ChronoUnit.DAYS)))
                .expiration(Date.from(Instant.now().minus(1, ChronoUnit.MINUTES)))
                .signWith(validKey)
                .compact();
        BizException expiredEx = assertThrows(BizException.class, () -> authService.parseToken(expiredToken));
        assertEquals(401, expiredEx.getCode());

        SecretKey wrongKey = Keys.hmacShaKeyFor("wrong-secret-key-must-be-at-least-32-bytes-long".getBytes(StandardCharsets.UTF_8));
        String wrongSigToken = Jwts.builder()
                .subject(DEFAULT_USER_ID)
                .issuedAt(new Date())
                .expiration(Date.from(Instant.now().plus(1, ChronoUnit.HOURS)))
                .signWith(wrongKey)
                .compact();
        BizException wrongEx = assertThrows(BizException.class, () -> authService.parseToken(wrongSigToken));
        assertEquals(401, wrongEx.getCode());
    }

    private SysUser buildUser(String username, String passwordHash) {
        SysUser user = new SysUser();
        user.setId(DEFAULT_USER_ID);
        user.setUsername(username);
        user.setPasswordHash(passwordHash);
        return user;
    }
}
