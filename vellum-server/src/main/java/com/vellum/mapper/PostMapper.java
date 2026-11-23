package com.vellum.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.vellum.entity.Post;
import org.apache.ibatis.annotations.Insert;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;
import org.apache.ibatis.annotations.Update;

import java.time.OffsetDateTime;
import java.util.List;

/**
 * 动态 / 长文表 Mapper（单表简单操作）。
 */
public interface PostMapper extends BaseMapper<Post> {

    /**
     * 统计未删除的动态与长文总条数。
     */
    @Select("SELECT COUNT(*) FROM post WHERE deleted = FALSE")
    long countAll();

    /**
     * 按记录时间倒序分页查询未删除记录。
     */
    @Select("SELECT id, type, title, content, location_city, record_time, deleted, created_at, updated_at "
            + "FROM post WHERE deleted = FALSE ORDER BY record_time DESC, id DESC LIMIT #{size} OFFSET #{offset}")
    List<Post> selectPage(@Param("size") int size, @Param("offset") int offset);

    /**
     * 插入一条动态或长文记录。
     */
    @Insert("INSERT INTO post (id, type, title, content, location_city, record_time, deleted, created_at, updated_at) "
            + "VALUES (#{id}, #{type}, #{title}, #{content}, #{locationCity}, #{recordTime}, #{deleted}, #{createdAt}, #{updatedAt})")
    int insertPost(Post post);

    /**
     * 逻辑删除指定动态或长文记录。
     */
    @Update("UPDATE post SET deleted = TRUE, updated_at = #{updatedAt} WHERE id = #{id} AND deleted = FALSE")
    int softDeleteById(@Param("id") String id, @Param("updatedAt") OffsetDateTime updatedAt);
}
