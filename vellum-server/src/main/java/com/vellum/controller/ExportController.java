package com.vellum.controller;

import com.vellum.common.BizException;
import com.vellum.common.Result;
import com.vellum.service.ExportService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.ContentDisposition;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.servlet.mvc.method.annotation.StreamingResponseBody;

import java.time.LocalDate;

/**
 * AI 导出接口（按时间段导出 .md 或含图 .zip）。
 */
@RestController
@RequestMapping("/api/v1/exports")
@RequiredArgsConstructor
@Slf4j
public class ExportController {

    private static final MediaType APPLICATION_ZIP = MediaType.parseMediaType("application/zip");

    private final ExportService exportService;

    @GetMapping("/markdown")
    public Result<Void> exportMarkdown() {
        // TODO: 按起止时间导出结构化 Markdown 文档
        throw new BizException(501, "接口尚未实现");
    }

    @GetMapping("/zip")
    public ResponseEntity<StreamingResponseBody> exportZip(
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate startDate,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate endDate,
            @RequestParam(required = false) String type) {
        log.info("导出 ZIP 包, startDate={}, endDate={}, type={}", startDate, endDate, type);
        ExportService.ExportPlan plan = exportService.prepareExport(startDate, endDate, type);
        ContentDisposition disposition = ContentDisposition.attachment()
                .filename(plan.zipFilename())
                .build();
        StreamingResponseBody body = outputStream -> exportService.writeZip(plan, outputStream);
        return ResponseEntity.ok()
                .contentType(APPLICATION_ZIP)
                .header(HttpHeaders.CONTENT_DISPOSITION, disposition.toString())
                .body(body);
    }
}
