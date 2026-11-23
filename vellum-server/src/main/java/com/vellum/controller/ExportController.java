package com.vellum.controller;

import com.vellum.common.BizException;
import com.vellum.common.Result;
import com.vellum.service.ExportService;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * AI 导出接口骨架（按时间段导出 .md 或含图 .zip）。
 */
@RestController
@RequestMapping("/api/v1/exports")
@RequiredArgsConstructor
public class ExportController {

    private final ExportService exportService;

    @GetMapping("/markdown")
    public Result<Void> exportMarkdown() {
        // TODO: 按起止时间导出结构化 Markdown 文档
        throw new BizException(501, "接口尚未实现");
    }

    @GetMapping("/zip")
    public Result<Void> exportZip() {
        // TODO: 按起止时间导出含 Markdown 正文与 MinIO 图片的 ZIP 包
        throw new BizException(501, "接口尚未实现");
    }
}
