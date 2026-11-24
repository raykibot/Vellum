package com.vellum;

import com.vellum.common.BizException;
import com.vellum.common.GlobalExceptionHandler;
import com.vellum.controller.PostController;
import com.vellum.dto.CreatePostRequest;
import com.vellum.dto.CursorPageResult;
import com.vellum.dto.PostItem;
import com.vellum.entity.Post;
import com.vellum.entity.PostImage;
import com.vellum.mapper.PostImageMapper;
import com.vellum.mapper.PostMapper;
import com.vellum.service.PostService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;

import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.ArgumentMatchers.isNull;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * 动态 / 长文游标分页、长文摘要截断、详情查询与图片绑定单元测试。
 */
@ExtendWith(MockitoExtension.class)
class PostServiceTest {

    @Mock
    private PostMapper postMapper;

    @Mock
    private PostImageMapper postImageMapper;

    private PostService postService;

    @BeforeEach
    void setUp() {
        postService = new PostService(postMapper, postImageMapper);
    }

    @Test
    void listShouldTruncateArticleSummaryKeepMomentFullAndAssembleImages() {
        String longBody = "## 暴雨夜的高架桥\n\n" + "九月的暴雨砸在高架桥隔音板上，像无数个无处可去的旧梦同时叩门。".repeat(6);
        Post article = buildPost("post-article", "ARTICLE", "暴雨夜的高架桥", longBody, "北京市");
        Post moment = buildPost("post-moment", "MOMENT", null, "吐槽段子全文", "杭州市");

        when(postMapper.selectCursorPage(isNull(), isNull(), isNull(), eq(6)))
                .thenReturn(List.of(article, moment));
        when(postImageMapper.selectByPostIds(List.of("post-article", "post-moment")))
                .thenReturn(List.of(
                        buildPostImage("img-1", "post-moment", 0),
                        buildPostImage("img-2", "post-moment", 1)
                ));

        CursorPageResult<PostItem> result = postService.list(5, null, null, null);

        assertEquals(5, result.size());
        assertFalse(result.hasMore());
        assertNull(result.nextCursorTime());
        assertNull(result.nextCursorId());
        assertEquals(2, result.items().size());

        PostItem articleItem = result.items().get(0);
        assertTrue(articleItem.contentTruncated());
        assertFalse(articleItem.content().startsWith("## 暴雨夜的高架桥"));
        assertTrue(articleItem.content().endsWith("..."));
        assertTrue(articleItem.content().length() <= 143);
        assertTrue(articleItem.images().isEmpty());

        PostItem momentItem = result.items().get(1);
        assertFalse(momentItem.contentTruncated());
        assertEquals("吐槽段子全文", momentItem.content());
        assertEquals(List.of("/api/v1/files/img-1", "/api/v1/files/img-2"), momentItem.images());
    }

    @Test
    void listShouldReturnHasMoreAndNextCursorWhenMoreItemsExist() {
        OffsetDateTime t1 = OffsetDateTime.parse("2026-11-24T08:00:00Z");
        OffsetDateTime t2 = OffsetDateTime.parse("2026-11-23T08:00:00Z");
        OffsetDateTime t3 = OffsetDateTime.parse("2026-11-22T08:00:00Z");

        Post p1 = buildPostWithTime("p1", "MOMENT", null, "第一条", "杭州市", t1);
        Post p2 = buildPostWithTime("p2", "MOMENT", null, "第二条", "上海市", t2);
        Post p3 = buildPostWithTime("p3", "MOMENT", null, "第三条", "北京市", t3);

        when(postMapper.selectCursorPage(isNull(), isNull(), isNull(), eq(3)))
                .thenReturn(List.of(p1, p2, p3));
        when(postImageMapper.selectByPostIds(List.of("p1", "p2"))).thenReturn(List.of());

        CursorPageResult<PostItem> result = postService.list(2, "ALL", null, null);

        assertTrue(result.hasMore());
        assertEquals(2, result.items().size());
        assertEquals(t2, result.nextCursorTime());
        assertEquals("p2", result.nextCursorId());
        verify(postImageMapper).selectByPostIds(List.of("p1", "p2"));
    }

    @Test
    void listShouldClampSizeAndPassTypeFilter() {
        Post post = buildPost("post-1", "MOMENT", null, "测试正文", "上海市");
        when(postMapper.selectCursorPage(eq("MOMENT"), isNull(), isNull(), eq(51)))
                .thenReturn(List.of(post));
        when(postImageMapper.selectByPostIds(List.of("post-1"))).thenReturn(List.of());

        CursorPageResult<PostItem> result = postService.list(100, "moment", null, null);

        assertEquals(50, result.size());
        assertFalse(result.hasMore());
        verify(postMapper).selectCursorPage("MOMENT", null, null, 51);
    }

    @Test
    void listShouldRejectHalfCursorOrInvalidFilterType() {
        OffsetDateTime now = OffsetDateTime.now(ZoneOffset.UTC);

        BizException halfCursor = assertThrows(BizException.class,
                () -> postService.list(10, null, now, "  "));
        assertEquals(400, halfCursor.getCode());

        BizException invalidType = assertThrows(BizException.class,
                () -> postService.list(10, "VIDEO", null, null));
        assertEquals(400, invalidType.getCode());

        verify(postMapper, never()).selectCursorPage(any(), any(), any(), anyInt());
    }

    @Test
    void listShouldShortCircuitWhenEmpty() {
        when(postMapper.selectCursorPage(isNull(), isNull(), isNull(), eq(13)))
                .thenReturn(List.of());

        CursorPageResult<PostItem> result = postService.list(12, null, null, null);

        assertFalse(result.hasMore());
        assertNull(result.nextCursorTime());
        assertNull(result.nextCursorId());
        assertTrue(result.items().isEmpty());
        verify(postImageMapper, never()).selectByPostIds(anyList());
    }

    @Test
    void controllerListShouldReturnCursorPageAndBindCursorParams() throws Exception {
        OffsetDateTime cursorTime = OffsetDateTime.parse("2026-11-22T01:15:00Z");
        Post article = buildPost("post-202", "ARTICLE", "小怪兽的孤独守恒定律", "完整正文".repeat(60), "杭州市");

        when(postMapper.selectCursorPage(eq("ARTICLE"), eq(cursorTime), eq("cursor-1"), eq(12)))
                .thenReturn(List.of(article));
        when(postImageMapper.selectByPostIds(List.of("post-202"))).thenReturn(List.of());

        MockMvc mockMvc = MockMvcBuilders
                .standaloneSetup(new PostController(postService))
                .setControllerAdvice(new GlobalExceptionHandler())
                .build();

        mockMvc.perform(get("/api/v1/posts")
                        .param("size", "11")
                        .param("type", "ARTICLE")
                        .param("cursorTime", "2026-11-22T01:15:00Z")
                        .param("cursorId", "cursor-1"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(0))
                .andExpect(jsonPath("$.data.size").value(11))
                .andExpect(jsonPath("$.data.hasMore").value(false))
                .andExpect(jsonPath("$.data.items[0].contentTruncated").value(true))
                .andExpect(jsonPath("$.data.items[0].images").isArray())
                .andExpect(jsonPath("$.data.items[0].images").isEmpty());
    }

    @Test
    void detailShouldReturnFullContentAndOrderedImages() {
        String fullMarkdown = "## 暴雨夜的高架桥\n\n" + "完整段落内容。".repeat(50);
        Post article = buildPost("post-201", "ARTICLE", "暴雨夜的高架桥", fullMarkdown, "北京市");

        when(postMapper.selectActiveById("post-201")).thenReturn(article);
        when(postImageMapper.selectByPostId("post-201"))
                .thenReturn(List.of(buildPostImage("img-10", "post-201", 0)));

        PostItem detail = postService.detail(" post-201 ");

        assertEquals("post-201", detail.id());
        assertEquals(fullMarkdown, detail.content());
        assertFalse(detail.contentTruncated());
        assertEquals(List.of("/api/v1/files/img-10"), detail.images());
    }

    @Test
    void detailShouldRejectBlankIdAndThrow404WhenMissing() {
        BizException blankEx = assertThrows(BizException.class, () -> postService.detail("   "));
        assertEquals(400, blankEx.getCode());

        when(postMapper.selectActiveById("missing")).thenReturn(null);
        BizException missingEx = assertThrows(BizException.class, () -> postService.detail("missing"));
        assertEquals(404, missingEx.getCode());
    }

    @Test
    void controllerDetailShouldReturnFullPostAnd404WhenMissing() throws Exception {
        Post article = buildPost("post-201", "ARTICLE", "标题", "完整长文内容", "杭州市");
        when(postMapper.selectActiveById("post-201")).thenReturn(article);
        when(postImageMapper.selectByPostId("post-201")).thenReturn(List.of());
        when(postMapper.selectActiveById("missing")).thenReturn(null);

        MockMvc mockMvc = MockMvcBuilders
                .standaloneSetup(new PostController(postService))
                .setControllerAdvice(new GlobalExceptionHandler())
                .build();

        mockMvc.perform(get("/api/v1/posts/post-201"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(0))
                .andExpect(jsonPath("$.data.id").value("post-201"))
                .andExpect(jsonPath("$.data.content").value("完整长文内容"))
                .andExpect(jsonPath("$.data.contentTruncated").value(false));

        mockMvc.perform(get("/api/v1/posts/missing"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(404));
    }

    @Test
    void createShouldInferArticleWhenTitlePresentAndNormalizeBlankCity() {
        when(postMapper.insertPost(any(Post.class))).thenReturn(1);

        PostItem item = postService.create(
                new CreatePostRequest("  暴雨夜随笔  ", null, "正文内容", "   ", null)
        );

        ArgumentCaptor<Post> captor = ArgumentCaptor.forClass(Post.class);
        verify(postMapper).insertPost(captor.capture());

        assertNotNull(item.id());
        assertEquals("ARTICLE", item.type());
        assertEquals("暴雨夜随笔", item.title());
        assertEquals("正文内容", item.content());
        assertFalse(item.contentTruncated());
        assertNull(item.locationCity());
        assertNotNull(item.recordTime());
        assertTrue(item.images().isEmpty());
        assertEquals("ARTICLE", captor.getValue().getType());
        assertFalse(captor.getValue().getDeleted());
    }

    @Test
    void createShouldInferMomentAndPreserveCustomRecordTime() {
        OffsetDateTime customTime = OffsetDateTime.parse("2026-11-20T10:00:00Z");
        when(postMapper.insertPost(any(Post.class))).thenReturn(1);

        PostItem item = postService.create(
                new CreatePostRequest("  ", null, "随手写一句", " 杭州市 ", customTime)
        );

        assertEquals("MOMENT", item.type());
        assertNull(item.title());
        assertEquals("杭州市", item.locationCity());
        assertEquals(customTime, item.recordTime());
        assertFalse(item.contentTruncated());
        assertTrue(item.images().isEmpty());
    }

    @Test
    void createShouldAllowPurePhotoMomentAndBindImagesInOrder() {
        when(postMapper.insertPost(any(Post.class))).thenReturn(1);
        when(postImageMapper.bindToPost(anyString(), anyString(), anyInt())).thenReturn(1);

        PostItem item = postService.create(
                new CreatePostRequest(null, "MOMENT", "   ", "杭州市", null, List.of(" img-a ", "img-b", "img-a"))
        );

        assertEquals("MOMENT", item.type());
        assertEquals("", item.content());
        assertFalse(item.contentTruncated());
        assertEquals(List.of("/api/v1/files/img-a", "/api/v1/files/img-b"), item.images());
        verify(postImageMapper).bindToPost("img-a", item.id(), 0);
        verify(postImageMapper).bindToPost("img-b", item.id(), 1);
    }

    @Test
    void createShouldRejectArticleWithoutContentEvenWhenImagesPresent() {
        BizException explicitArticle = assertThrows(BizException.class,
                () -> postService.create(new CreatePostRequest("标题", "ARTICLE", "   ", null, null, List.of("img-1"))));
        assertEquals(400, explicitArticle.getCode());

        BizException inferredArticle = assertThrows(BizException.class,
                () -> postService.create(new CreatePostRequest("仅标题无正文", null, "   ", null, null, List.of("img-1"))));
        assertEquals(400, inferredArticle.getCode());

        verify(postMapper, never()).insertPost(any());
    }

    @Test
    void createShouldRejectWhenBothContentAndImagesAreEmpty() {
        BizException ex = assertThrows(BizException.class,
                () -> postService.create(new CreatePostRequest(null, "MOMENT", "   ", null, null, List.of())));

        assertEquals(400, ex.getCode());
        verify(postMapper, never()).insertPost(any());
    }

    @Test
    void createShouldRejectMissingOrAlreadyBoundImages() {
        when(postMapper.insertPost(any(Post.class))).thenReturn(1);
        when(postImageMapper.bindToPost(eq("img-1"), anyString(), eq(0))).thenReturn(1);
        when(postImageMapper.bindToPost(eq("img-2"), anyString(), eq(1))).thenReturn(0);

        BizException ex = assertThrows(BizException.class,
                () -> postService.create(new CreatePostRequest(null, "MOMENT", "配图动态", null, null, List.of("img-1", "img-2"))));

        assertEquals(400, ex.getCode());
    }

    @Test
    void createShouldRejectMoreThanNineImages() {
        List<String> tenIds = List.of("1", "2", "3", "4", "5", "6", "7", "8", "9", "10");

        BizException ex = assertThrows(BizException.class,
                () -> postService.create(new CreatePostRequest(null, "MOMENT", "十张图", null, null, tenIds)));

        assertEquals(400, ex.getCode());
        verify(postMapper, never()).insertPost(any());
    }

    @Test
    void createShouldRejectInvalidType() {
        BizException ex = assertThrows(BizException.class,
                () -> postService.create(new CreatePostRequest(null, "VIDEO", "正文", null, null)));

        assertEquals(400, ex.getCode());
        verify(postMapper, never()).insertPost(any());
    }

    @Test
    void controllerCreateShouldValidateAndReturnPostItem() throws Exception {
        when(postMapper.insertPost(any(Post.class))).thenReturn(1);

        MockMvc mockMvc = MockMvcBuilders
                .standaloneSetup(new PostController(postService))
                .setControllerAdvice(new GlobalExceptionHandler())
                .build();

        mockMvc.perform(post("/api/v1/posts")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"content\":\"下班买了一杯热美式\",\"locationCity\":\"杭州市\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(0))
                .andExpect(jsonPath("$.data.id").isNotEmpty())
                .andExpect(jsonPath("$.data.type").value("MOMENT"))
                .andExpect(jsonPath("$.data.locationCity").value("杭州市"))
                .andExpect(jsonPath("$.data.contentTruncated").value(false))
                .andExpect(jsonPath("$.data.images").isArray())
                .andExpect(jsonPath("$.data.images").isEmpty());

        mockMvc.perform(post("/api/v1/posts")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"content\":\"   \"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(400));
    }

    @Test
    void deleteShouldSoftDeletePostAndImages() {
        when(postMapper.softDeleteById(eq("post-1"), any(OffsetDateTime.class))).thenReturn(1);

        postService.delete(" post-1 ");

        verify(postMapper).softDeleteById(eq("post-1"), any(OffsetDateTime.class));
        verify(postImageMapper).softDeleteByPostId("post-1");
    }

    @Test
    void deleteShouldThrow404WhenNotFoundOrAlreadyDeleted() {
        when(postMapper.softDeleteById(eq("missing"), any(OffsetDateTime.class))).thenReturn(0);

        BizException ex = assertThrows(BizException.class, () -> postService.delete("missing"));

        assertEquals(404, ex.getCode());
        verify(postImageMapper, never()).softDeleteByPostId(anyString());
    }

    @Test
    void deleteShouldRejectBlankId() {
        BizException ex = assertThrows(BizException.class, () -> postService.delete("   "));

        assertEquals(400, ex.getCode());
        verify(postMapper, never()).softDeleteById(anyString(), any());
    }

    @Test
    void controllerDeleteShouldReturnOkAnd404WhenMissing() throws Exception {
        when(postMapper.softDeleteById(eq("post-1"), any(OffsetDateTime.class))).thenReturn(1);
        when(postMapper.softDeleteById(eq("missing"), any(OffsetDateTime.class))).thenReturn(0);

        MockMvc mockMvc = MockMvcBuilders
                .standaloneSetup(new PostController(postService))
                .setControllerAdvice(new GlobalExceptionHandler())
                .build();

        mockMvc.perform(delete("/api/v1/posts/post-1"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(0));

        mockMvc.perform(delete("/api/v1/posts/missing"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(404));
    }

    private Post buildPost(String id, String type, String title, String content, String city) {
        return buildPostWithTime(id, type, title, content, city, OffsetDateTime.now(ZoneOffset.UTC));
    }

    private Post buildPostWithTime(
            String id,
            String type,
            String title,
            String content,
            String city,
            OffsetDateTime recordTime) {
        OffsetDateTime now = OffsetDateTime.now(ZoneOffset.UTC);
        Post post = new Post();
        post.setId(id);
        post.setType(type);
        post.setTitle(title);
        post.setContent(content);
        post.setLocationCity(city);
        post.setRecordTime(recordTime);
        post.setCreatedAt(now);
        post.setUpdatedAt(now);
        return post;
    }

    private PostImage buildPostImage(String id, String postId, int sortOrder) {
        PostImage image = new PostImage();
        image.setId(id);
        image.setPostId(postId);
        image.setObjectName("2026/11/" + id + ".jpg");
        image.setSortOrder(sortOrder);
        image.setDeleted(false);
        image.setCreatedAt(OffsetDateTime.now(ZoneOffset.UTC));
        return image;
    }
}
