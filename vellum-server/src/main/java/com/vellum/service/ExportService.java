package com.vellum.service;

import com.vellum.mapper.PostImageMapper;
import com.vellum.mapper.PostMapper;
import io.minio.MinioClient;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

/**
 * AI 导出服务骨架。
 *
 * <p>规划职责：按时间段查询动态正文，拼装结构化 Markdown 文档，并从 MinIO 拉取关联图片打包为 .md 或 .zip。
 */
@Service
@RequiredArgsConstructor
public class ExportService {

    private final PostMapper postMapper;
    private final PostImageMapper postImageMapper;
    private final MinioClient minioClient;

    // TODO: 骨架验收后实现按时间区间导出 .md 与含图 .zip 逻辑
}
