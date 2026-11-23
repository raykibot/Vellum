package com.vellum.service;

import com.vellum.common.BizException;
import com.vellum.dto.CreatePostRequest;
import com.vellum.dto.PageResult;
import com.vellum.dto.PostItem;
import com.vellum.entity.Post;
import com.vellum.mapper.PostImageMapper;
import com.vellum.mapper.PostMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Locale;
import java.util.UUID;

/**
 * 动态 / 长文业务服务。
 */
@Service
@RequiredArgsConstructor
public class PostService {

    private static final int MAX_PAGE_SIZE = 50;
    private static final String TYPE_MOMENT = "MOMENT";
    private static final String TYPE_ARTICLE = "ARTICLE";

    private final PostMapper postMapper;
    private final PostImageMapper postImageMapper;

    /**
     * 按记录时间倒序分页查询统一时间流（单页返回完整正文，图片链接暂返回 null）。
     */
    public PageResult<PostItem> list(int page, int size) {
        int safePage = Math.max(1, page);
        int safeSize = Math.min(MAX_PAGE_SIZE, Math.max(1, size));
        int offset = (safePage - 1) * safeSize;

        long total = postMapper.countAll();
        if (total == 0) {
            return new PageResult<>(safePage, safeSize, 0L, List.of());
        }

        List<PostItem> items = postMapper.selectPage(safeSize, offset).stream()
                .map(this::toPostItem)
                .toList();
        return new PageResult<>(safePage, safeSize, total, items);
    }

    /**
     * 发布一条动态或长文（图片绑定待 FileController 接入后补充）。
     */
    public PostItem create(CreatePostRequest request) {
        String title = trimToNull(request.title());
        String locationCity = trimToNull(request.locationCity());
        String type = resolvePostType(request.type(), title);

        OffsetDateTime now = OffsetDateTime.now(ZoneOffset.UTC);
        OffsetDateTime recordTime = request.recordTime() != null ? request.recordTime() : now;

        Post post = new Post();
        post.setId(UUID.randomUUID().toString());
        post.setType(type);
        post.setTitle(title);
        post.setContent(request.content());
        post.setLocationCity(locationCity);
        post.setRecordTime(recordTime);
        post.setDeleted(false);
        post.setCreatedAt(now);
        post.setUpdatedAt(now);

        postMapper.insertPost(post);
        return toPostItem(post);
    }

    /**
     * 逻辑删除动态或长文，并同步逻辑删除关联图片记录（保留 MinIO 文件暂不清理）。
     */
    @Transactional(rollbackFor = Exception.class)
    public void delete(String id) {
        String cleanId = trimToNull(id);
        if (cleanId == null) {
            throw new BizException(400, "记录 ID 不能为空");
        }

        OffsetDateTime now = OffsetDateTime.now(ZoneOffset.UTC);
        int updated = postMapper.softDeleteById(cleanId, now);
        if (updated == 0) {
            throw new BizException(404, "记录不存在");
        }

        postImageMapper.softDeleteByPostId(cleanId);
    }

    private String resolvePostType(String rawType, String title) {
        String normalized = trimToNull(rawType);
        if (normalized == null) {
            return title != null ? TYPE_ARTICLE : TYPE_MOMENT;
        }
        String upper = normalized.toUpperCase(Locale.ROOT);
        if (!TYPE_MOMENT.equals(upper) && !TYPE_ARTICLE.equals(upper)) {
            throw new BizException(400, "不支持的内容类型，仅允许 MOMENT 或 ARTICLE");
        }
        return upper;
    }

    private String trimToNull(String value) {
        if (value == null) {
            return null;
        }
        String trimmed = value.trim();
        return trimmed.isEmpty() ? null : trimmed;
    }

    private PostItem toPostItem(Post post) {
        return new PostItem(
                post.getId(),
                post.getType(),
                post.getTitle(),
                post.getContent(),
                post.getLocationCity(),
                post.getRecordTime(),
                post.getCreatedAt(),
                post.getUpdatedAt(),
                null
        );
    }

    // TODO: 后续实现详情、编辑、删除与文档导入导出
}
