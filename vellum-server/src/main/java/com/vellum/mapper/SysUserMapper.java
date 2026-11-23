package com.vellum.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.vellum.entity.SysUser;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;

/**
 * 用户表 Mapper（单表简单操作）。
 */
public interface SysUserMapper extends BaseMapper<SysUser> {

    /**
     * 根据用户名查询用户记录。
     */
    @Select("SELECT id, username, password_hash, created_at FROM sys_user WHERE username = #{username} LIMIT 1")
    SysUser selectByUsername(@Param("username") String username);
}
