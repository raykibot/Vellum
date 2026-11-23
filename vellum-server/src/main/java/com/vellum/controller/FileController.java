package com.vellum.controller;

import com.vellum.common.BizException;
import com.vellum.common.Result;
import com.vellum.service.FileService;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * 图片上传与访问接口骨架（基于 MinIO）。
 */
@RestController
@RequestMapping("/api/v1/files")
@RequiredArgsConstructor
public class FileController {

    private final FileService fileService;

    @PostMapping("/upload")
    public Result<Void> upload() {
        // TODO: 压缩上传图片至 MinIO 并返回图片 ID 与访问地址
        throw new BizException(501, "接口尚未实现");
    }

    @GetMapping("/{id}")
    public Result<Void> view(@PathVariable String id) {
        // TODO: 从 MinIO 读取图片流或重定向至预签名地址
        throw new BizException(501, "接口尚未实现");
    }
}
