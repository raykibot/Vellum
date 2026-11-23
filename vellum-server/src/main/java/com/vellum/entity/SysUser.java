package com.vellum.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

import java.time.OffsetDateTime;

/**
 * 用户实体，对应表 sys_user。
 */
@Data
@TableName("sys_user")
public class SysUser {

    @TableId(type = IdType.INPUT)
    private String id;

    private String username;

    private String passwordHash;

    private OffsetDateTime createdAt;
}
