package com.vellum.service;

import com.vellum.mapper.PostImageMapper;
import io.minio.MinioClient;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

/**
 * 图片压缩与 MinIO 对象存储服务骨架。
 *
 * <p>规划职责：压缩上传图片至 MinIO、记录 post_image 映射、读取或生成图片访问地址。
 */
@Service
@RequiredArgsConstructor
public class FileService {

    private final MinioClient minioClient;
    private final PostImageMapper postImageMapper;

    // TODO: 骨架验收后实现图片压缩上传至 MinIO 与读取逻辑
}
