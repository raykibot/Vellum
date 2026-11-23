package com.vellum.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

import java.time.OffsetDateTime;

/**
 * 图片实体，对应表 post_image（逻辑关联 post.id，实际文件存 MinIO）。
 */
@Data
@TableName("post_image")
public class PostImage {

    @TableId(type = IdType.INPUT)
    private String id;

    private String postId;

    private String objectName;

    private Integer sortOrder;

    private Boolean deleted;

    private OffsetDateTime createdAt;
}
