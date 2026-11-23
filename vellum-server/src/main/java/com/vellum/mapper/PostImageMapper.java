package com.vellum.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.vellum.entity.PostImage;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Update;

/**
 * 图片逻辑关联表 Mapper（单表简单操作）。
 */
public interface PostImageMapper extends BaseMapper<PostImage> {

    /**
     * 逻辑删除指定动态下的关联图片记录。
     */
    @Update("UPDATE post_image SET deleted = TRUE WHERE post_id = #{postId} AND deleted = FALSE")
    int softDeleteByPostId(@Param("postId") String postId);
}
