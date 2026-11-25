package com.vellum;

import org.mybatis.spring.annotation.MapperScan;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

import java.util.TimeZone;

/**
 * 素笺（Vellum）服务端启动入口。
 */
@SpringBootApplication
@MapperScan("com.vellum.mapper")
public class VellumApplication {

    public static void main(String[] args) {
        TimeZone.setDefault(TimeZone.getTimeZone("Asia/Shanghai"));
        SpringApplication.run(VellumApplication.class, args);
    }
}
