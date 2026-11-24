package com.vellum.service;

import com.vellum.common.BizException;
import com.vellum.dto.CreatePostRequest;
import com.vellum.dto.CursorPageResult;
import com.vellum.dto.PostItem;
import com.vellum.entity.Post;
import com.vellum.entity.PostImage;
import com.vellum.mapper.PostImageMapper;
import com.vellum.mapper.PostMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.UUID;

/**
 * 动态 / 长文业务服务。
 */
@Service
@RequiredArgsConstructor
public class PostService {

    private static final int MAX_PAGE_SIZE = 50;
    private static final int MAX_IMAGE_COUNT = 9;
    private static final int ARTICLE_SUMMARY_MAX_CHARS = 140;
    private static final String TYPE_ALL = "ALL";
    private static final String TYPE_MOMENT = "MOMENT";
    private static final String TYPE_ARTICLE = "ARTICLE";

    private final PostMapper postMapper;
    private final PostImageMapper postImageMapper;

    /**
     * 游标分页查询统一时间流（支持按类型筛选；长文仅返回摘要并标记 contentTruncated）。
     */
    public CursorPageResult<PostItem> list(
            int size,
            String rawType,
            OffsetDateTime cursorTime,
            String rawCursorId) {
        int safeSize = Math.min(MAX_PAGE_SIZE, Math.max(1, size));
        String filterType = resolveFilterType(rawType);
        String cleanCursorId = trimToNull(rawCursorId);
        if ((cursorTime == null) != (cleanCursorId == null)) {
            throw new BizException(400, "游标参数 cursorTime 与 cursorId 必须同时传入");
        }

        List<Post> fetched = postMapper.selectCursorPage(filterType, cursorTime, cleanCursorId, safeSize + 1);
        if (fetched == null || fetched.isEmpty()) {
            return new CursorPageResult<>(safeSize, false, null, null, List.of());
        }

        boolean hasMore = fetched.size() > safeSize;
        List<Post> pagePosts = hasMore ? fetched.subList(0, safeSize) : fetched;

        Map<String, List<String>> imagesByPostId = loadImagesByPostIds(pagePosts);
        List<PostItem> items = pagePosts.stream()
                .map(post -> toListItem(post, imagesByPostId.getOrDefault(post.getId(), List.of())))
                .toList();

        OffsetDateTime nextCursorTime = null;
        String nextCursorId = null;
        if (hasMore) {
            Post last = pagePosts.get(pagePosts.size() - 1);
            nextCursorTime = last.getRecordTime();
            nextCursorId = last.getId();
        }
        return new CursorPageResult<>(safeSize, hasMore, nextCursorTime, nextCursorId, items);
    }

    /**
     * 按需查询单条动态或长文的完整正文与关联图片。
     */
    public PostItem detail(String id) {
        String cleanId = trimToNull(id);
        if (cleanId == null) {
            throw new BizException(400, "记录 ID 不能为空");
        }

        Post post = postMapper.selectActiveById(cleanId);
        if (post == null) {
            throw new BizException(404, "记录不存在");
        }

        List<PostImage> postImages = postImageMapper.selectByPostId(cleanId);
        List<String> imageUrls = postImages == null ? List.of() : postImages.stream()
                .map(image -> FileService.buildImageUrl(image.getId()))
                .toList();
        return toPostItem(post, post.getContent(), imageUrls, false);
    }

    /**
     * 发布一条动态或长文（仅动态支持纯图发布；存在图片时在同一事务内顺序绑定 post_image）。
     */
    @Transactional(rollbackFor = Exception.class)
    public PostItem create(CreatePostRequest request) {
        String title = trimToNull(request.title());
        String locationCity = trimToNull(request.locationCity());
        String content = normalizeContent(request.content());
        List<String> cleanImageIds = normalizeImageIds(request.imageIds());
        String type = resolvePostType(request.type(), title);

        if (TYPE_ARTICLE.equals(type) && content.isEmpty()) {
            throw new BizException(400, "长文正文内容不能为空");
        }
        if (content.isEmpty() && cleanImageIds.isEmpty()) {
            throw new BizException(400, "正文内容和图片不能同时为空");
        }
        OffsetDateTime now = OffsetDateTime.now(ZoneOffset.UTC);
        OffsetDateTime recordTime = request.recordTime() != null ? request.recordTime() : now;

        Post post = new Post();
        post.setId(UUID.randomUUID().toString());
        post.setType(type);
        post.setTitle(title);
        post.setContent(content);
        post.setLocationCity(locationCity);
        post.setRecordTime(recordTime);
        post.setDeleted(false);
        post.setCreatedAt(now);
        post.setUpdatedAt(now);

        postMapper.insertPost(post);

        if (!cleanImageIds.isEmpty()) {
            bindImagesToPost(post.getId(), cleanImageIds);
        }

        List<String> imageUrls = cleanImageIds.stream()
                .map(FileService::buildImageUrl)
                .toList();
        return toPostItem(post, post.getContent(), imageUrls, false);
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

    private Map<String, List<String>> loadImagesByPostIds(List<Post> posts) {
        List<String> postIds = posts.stream().map(Post::getId).toList();
        List<PostImage> postImages = postImageMapper.selectByPostIds(postIds);
        Map<String, List<String>> grouped = new HashMap<>();
        if (postImages == null || postImages.isEmpty()) {
            return grouped;
        }
        for (PostImage image : postImages) {
            grouped.computeIfAbsent(image.getPostId(), key -> new ArrayList<>())
                    .add(FileService.buildImageUrl(image.getId()));
        }
        return grouped;
    }

    private void bindImagesToPost(String postId, List<String> imageIds) {
        for (int i = 0; i < imageIds.size(); i++) {
            int updated = postImageMapper.bindToPost(imageIds.get(i), postId, i);
            if (updated != 1) {
                throw new BizException(400, "部分图片不存在或已被绑定");
            }
        }
    }

    private List<String> normalizeImageIds(List<String> rawIds) {
        if (rawIds == null || rawIds.isEmpty()) {
            return List.of();
        }
        Set<String> deduplicated = new LinkedHashSet<>();
        for (String rawId : rawIds) {
            String trimmed = trimToNull(rawId);
            if (trimmed != null) {
                deduplicated.add(trimmed);
            }
        }
        if (deduplicated.size() > MAX_IMAGE_COUNT) {
            throw new BizException(400, "单条记录最多上传9张图片");
        }
        return List.copyOf(deduplicated);
    }

    private String normalizeContent(String rawContent) {
        if (rawContent == null || rawContent.trim().isEmpty()) {
            return "";
        }
        return rawContent;
    }

    private String resolveFilterType(String rawType) {
        String normalized = trimToNull(rawType);
        if (normalized == null) {
            return null;
        }
        String upper = normalized.toUpperCase(Locale.ROOT);
        if (TYPE_ALL.equals(upper)) {
            return null;
        }
        if (!TYPE_MOMENT.equals(upper) && !TYPE_ARTICLE.equals(upper)) {
            throw new BizException(400, "不支持的内容类型，仅允许 ALL、MOMENT 或 ARTICLE");
        }
        return upper;
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

    private PostItem toListItem(Post post, List<String> images) {
        if (!TYPE_ARTICLE.equals(post.getType())) {
            return toPostItem(post, post.getContent(), images, false);
        }
        String summary = buildArticleSummary(post.getContent(), post.getTitle());
        boolean truncated = !summary.equals(post.getContent());
        return toPostItem(post, summary, images, truncated);
    }

    private String buildArticleSummary(String rawContent, String title) {
        if (rawContent == null || rawContent.isBlank()) {
            return "";
        }
        String stripped = stripDuplicateLeadingHeading(rawContent, title).trim();
        if (stripped.length() <= ARTICLE_SUMMARY_MAX_CHARS) {
            return stripped;
        }
        return stripped.substring(0, ARTICLE_SUMMARY_MAX_CHARS).trim() + "...";
    }

    private String stripDuplicateLeadingHeading(String rawContent, String title) {
        String normalized = rawContent.replace("\r\n", "\n");
        if (title == null || title.isBlank()) {
            return normalized;
        }
        String[] lines = normalized.split("\n", -1);
        int firstIdx = 0;
        while (firstIdx < lines.length && lines[firstIdx].trim().isEmpty()) {
            firstIdx++;
        }
        if (firstIdx >= lines.length) {
            return normalized;
        }
        String firstLine = lines[firstIdx].trim();
        String trimmedTitle = title.trim();
        if (firstLine.matches("^#{1,3}\\s+.*")) {
            String headingText = firstLine.replaceFirst("^#{1,3}\\s+", "").trim();
            if (headingText.equals(trimmedTitle)) {
                int nextIdx = firstIdx + 1;
                while (nextIdx < lines.length && lines[nextIdx].trim().isEmpty()) {
                    nextIdx++;
                }
                StringBuilder sb = new StringBuilder();
                for (int i = nextIdx; i < lines.length; i++) {
                    if (sb.length() > 0) {
                        sb.append('\n');
                    }
                    sb.append(lines[i]);
                }
                return sb.toString();
            }
        }
        return normalized;
    }

    private PostItem toPostItem(Post post, String content, List<String> images, boolean contentTruncated) {
        return new PostItem(
                post.getId(),
                post.getType(),
                post.getTitle(),
                content,
                post.getLocationCity(),
                post.getRecordTime(),
                post.getCreatedAt(),
                post.getUpdatedAt(),
                images,
                contentTruncated
        );
    }
}
