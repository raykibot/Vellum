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
 * 动态 / 长文表 Mapper（单表简单操作，游标筛选查询在 XML 中维护）。
 */
public interface PostMapper extends BaseMapper<Post> {

    /**
     * 按记录 ID 查询单条未删除记录（用于详情页按需获取完整正文）。
     */
    @Select("SELECT id, type, title, content, location_city, record_time, deleted, created_at, updated_at "
            + "FROM post WHERE id = #{id} AND deleted = FALSE LIMIT 1")
    Post selectActiveById(@Param("id") String id);

    /**
     * 游标分页查询未删除记录（支持类型筛选与多查 1 条判断 hasMore）。
     */
    List<Post> selectCursorPage(
            @Param("type") String type,
            @Param("cursorTime") OffsetDateTime cursorTime,
            @Param("cursorId") String cursorId,
            @Param("limit") int limit
    );

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
