package com.vellum;

import org.mybatis.spring.annotation.MapperScan;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

/**
 * 素笺（Vellum）服务端启动入口。
 */
@SpringBootApplication
@MapperScan("com.vellum.mapper")
public class VellumApplication {

    public static void main(String[] args) {
        SpringApplication.run(VellumApplication.class, args);
    }
}
