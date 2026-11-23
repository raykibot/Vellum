package com.vellum;

import com.vellum.common.Result;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;

/**
 * 骨架阶段基础测试占位。
 */
class VellumApplicationTests {

    @Test
    void resultShouldWrapResponse() {
        Result<String> ok = Result.ok("vellum");
        assertEquals(0, ok.code());
        assertEquals("vellum", ok.data());

        Result<Void> fail = Result.fail(501, "接口尚未实现");
        assertEquals(501, fail.code());
        assertNull(fail.data());
    }
}
