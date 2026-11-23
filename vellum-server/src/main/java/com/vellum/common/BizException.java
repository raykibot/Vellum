package com.vellum.common;

import lombok.Getter;

/**
 * 统一业务异常。
 */
@Getter
public class BizException extends RuntimeException {

    private final int code;

    public BizException(int code, String message) {
        super(message);
        this.code = code;
    }
}
