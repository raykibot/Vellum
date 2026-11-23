package com.vellum.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

import java.time.OffsetDateTime;

/**
 * 动态 / 长文主实体，对应表 post。
 */
@Data
@TableName("post")
public class Post {

    @TableId(type = IdType.INPUT)
    private String id;

    /**
     * 内容类型：MOMENT（短动态）/ ARTICLE（长文）。
     */
    private String type;

    private String title;

    private String content;

    /**
     * 仅存城市名（如“杭州市”），未定位或失败时为 null。
     */
    private String locationCity;

    private OffsetDateTime recordTime;

    private Boolean deleted;

    private OffsetDateTime createdAt;

    private OffsetDateTime updatedAt;
}
