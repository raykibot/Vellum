package com.vellum.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.vellum.entity.PostImage;
import org.apache.ibatis.annotations.Insert;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;
import org.apache.ibatis.annotations.Update;

import java.util.List;

/**
 * 图片逻辑关联表 Mapper（单表操作，复杂批量 IN 查询在 XML 中维护）。
 */
public interface PostImageMapper extends BaseMapper<PostImage> {

    /**
     * 插入一条已上传至 MinIO 的图片记录（初始 post_id 为 NULL）。
     */
    @Insert("INSERT INTO post_image (id, post_id, object_name, sort_order, deleted, created_at) "
            + "VALUES (#{id}, #{postId}, #{objectName}, #{sortOrder}, #{deleted}, #{createdAt})")
    int insertImage(PostImage image);

    /**
     * 根据图片 ID 查询未删除的单条图片元数据。
     */
    @Select("SELECT id, post_id, object_name, sort_order, deleted, created_at "
            + "FROM post_image WHERE id = #{id} AND deleted = FALSE LIMIT 1")
    PostImage selectActiveById(@Param("id") String id);

    /**
     * 将尚未绑定的图片逻辑关联至指定动态并写入排序值。
     */
    @Update("UPDATE post_image SET post_id = #{postId}, sort_order = #{sortOrder} "
            + "WHERE id = #{id} AND deleted = FALSE AND post_id IS NULL")
    int bindToPost(@Param("id") String id, @Param("postId") String postId, @Param("sortOrder") int sortOrder);

    /**
     * 逻辑删除指定动态下的关联图片记录。
     */
    @Update("UPDATE post_image SET deleted = TRUE WHERE post_id = #{postId} AND deleted = FALSE")
    int softDeleteByPostId(@Param("postId") String postId);

    /**
     * 查询单条动态关联的未删除图片（按 sort_order 升序）。
     */
    @Select("SELECT id, post_id, object_name, sort_order, deleted, created_at "
            + "FROM post_image WHERE deleted = FALSE AND post_id = #{postId} "
            + "ORDER BY sort_order ASC, created_at ASC")
    List<PostImage> selectByPostId(@Param("postId") String postId);

    /**
     * 批量查询多条动态关联的未删除图片（按 sort_order 升序）。
     */
    List<PostImage> selectByPostIds(@Param("postIds") List<String> postIds);
}
