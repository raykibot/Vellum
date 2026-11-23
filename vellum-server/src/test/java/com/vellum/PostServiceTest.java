package com.vellum;

import com.vellum.common.BizException;
import com.vellum.common.GlobalExceptionHandler;
import com.vellum.controller.PostController;
import com.vellum.dto.CreatePostRequest;
import com.vellum.dto.PageResult;
import com.vellum.dto.PostItem;
import com.vellum.entity.Post;
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

import static org.hamcrest.Matchers.nullValue;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * 动态 / 长文时间线列表单元测试。
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
    void listShouldReturnFullContentAndNullImages() {
        Post moment = buildPost("00000000-0000-0000-0000-000000000101", "MOMENT", null, "吐槽段子全文", "杭州市");
        Post article = buildPost("00000000-0000-0000-0000-000000000201", "ARTICLE", "暴雨夜的高架桥", "长文完整正文", "北京市");

        when(postMapper.countAll()).thenReturn(2L);
        when(postMapper.selectPage(5, 0)).thenReturn(List.of(article, moment));

        PageResult<PostItem> result = postService.list(1, 5);

        assertEquals(1, result.page());
        assertEquals(5, result.size());
        assertEquals(2L, result.total());
        assertEquals(2, result.items().size());
        assertEquals("长文完整正文", result.items().get(0).content());
        assertNull(result.items().get(0).images());
        assertNull(result.items().get(1).images());
    }

    @Test
    void listShouldClampInvalidPageAndSize() {
        Post post = buildPost("00000000-0000-0000-0000-000000000101", "MOMENT", null, "测试正文", "上海市");
        when(postMapper.countAll()).thenReturn(1L);
        when(postMapper.selectPage(50, 0)).thenReturn(List.of(post));

        PageResult<PostItem> result = postService.list(0, 100);

        assertEquals(1, result.page());
        assertEquals(50, result.size());
        verify(postMapper).selectPage(50, 0);
    }

    @Test
    void listShouldShortCircuitWhenTotalIsZero() {
        when(postMapper.countAll()).thenReturn(0L);

        PageResult<PostItem> result = postService.list(1, 5);

        assertEquals(0L, result.total());
        assertTrue(result.items().isEmpty());
        verify(postMapper, never()).selectPage(anyInt(), anyInt());
    }

    @Test
    void controllerListShouldDefaultToFiveItemsAndNullImages() throws Exception {
        Post article = buildPost("00000000-0000-0000-0000-000000000202", "ARTICLE", "小怪兽的孤独守恒定律", "完整正文", "杭州市");
        when(postMapper.countAll()).thenReturn(1L);
        when(postMapper.selectPage(5, 0)).thenReturn(List.of(article));

        MockMvc mockMvc = MockMvcBuilders
                .standaloneSetup(new PostController(postService))
                .setControllerAdvice(new GlobalExceptionHandler())
                .build();

        mockMvc.perform(get("/api/v1/posts"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(0))
                .andExpect(jsonPath("$.data.page").value(1))
                .andExpect(jsonPath("$.data.size").value(5))
                .andExpect(jsonPath("$.data.total").value(1))
                .andExpect(jsonPath("$.data.items[0].content").value("完整正文"))
                .andExpect(jsonPath("$.data.items[0].images").value(nullValue()));
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
        assertNull(item.locationCity());
        assertNotNull(item.recordTime());
        assertNull(item.images());
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
        assertNull(item.images());
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
                .andExpect(jsonPath("$.data.images").value(nullValue()));

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
        OffsetDateTime now = OffsetDateTime.now(ZoneOffset.UTC);
        Post post = new Post();
        post.setId(id);
        post.setType(type);
        post.setTitle(title);
        post.setContent(content);
        post.setLocationCity(city);
        post.setRecordTime(now);
        post.setCreatedAt(now);
        post.setUpdatedAt(now);
        return post;
    }
}
