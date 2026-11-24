package com.vellum.controller;

import com.vellum.common.BizException;
import com.vellum.common.Result;
import com.vellum.dto.CreatePostRequest;
import com.vellum.dto.CursorPageResult;
import com.vellum.dto.PostItem;
import com.vellum.service.PostService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.time.OffsetDateTime;

/**
 * 动态 / 长文与文档读写接口。
 */
@RestController
@RequestMapping("/api/v1/posts")
@RequiredArgsConstructor
@Slf4j
public class PostController {

    private final PostService postService;

    @GetMapping
    public Result<CursorPageResult<PostItem>> list(
            @RequestParam(defaultValue = "12") int size,
            @RequestParam(required = false) String type,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) OffsetDateTime cursorTime,
            @RequestParam(required = false) String cursorId) {
        log.info("分页查询时间流, size={}, type={}", size, type);
        try {
            return Result.ok(postService.list(size, type, cursorTime, cursorId));
        } catch (BizException e) {
            log.warn("分页查询时间流失败, size={}, type={}, code={}, message={}",
                    size, type, e.getCode(), e.getMessage(), e);
            return Result.fail(e.getCode(), e.getMessage());
        } catch (Exception e) {
            log.error("分页查询时间流异常, size={}, type={}", size, type, e);
            return Result.fail(500, "查询失败");
        }
    }

    @GetMapping("/{id}")
    public Result<PostItem> detail(@PathVariable String id) {
        log.info("查询记录详情, id={}", id);
        try {
            return Result.ok(postService.detail(id));
        } catch (BizException e) {
            log.warn("查询记录详情失败, id={}, code={}, message={}",
                    id, e.getCode(), e.getMessage(), e);
            return Result.fail(e.getCode(), e.getMessage());
        } catch (Exception e) {
            log.error("查询记录详情异常, id={}", id, e);
            return Result.fail(500, "查询详情失败");
        }
    }

    @PostMapping
    public Result<PostItem> create(@Valid @RequestBody CreatePostRequest request) {
        log.info("发布动态");
        try {
            return Result.ok(postService.create(request));
        } catch (BizException e) {
            log.warn("发布动态失败, type={}, code={}, message={}",
                    request.type(), e.getCode(), e.getMessage(), e);
            return Result.fail(e.getCode(), e.getMessage());
        } catch (Exception e) {
            log.error("发布动态异常, type={}", request.type(), e);
            return Result.fail(500, "发布失败");
        }
    }

    @PutMapping("/{id}")
    public Result<Void> update(@PathVariable String id) {
        // TODO: 编辑已有动态或长文
        throw new BizException(501, "接口尚未实现");
    }

    @DeleteMapping("/{id}")
    public Result<Void> delete(@PathVariable String id) {
        log.info("删除动态, id={}", id);
        try {
            postService.delete(id);
            return Result.ok();
        } catch (BizException e) {
            log.warn("删除动态失败, id={}, code={}, message={}",
                    id, e.getCode(), e.getMessage(), e);
            return Result.fail(e.getCode(), e.getMessage());
        } catch (Exception e) {
            log.error("删除动态异常, id={}", id, e);
            return Result.fail(500, "删除失败");
        }
    }

    @PostMapping("/import")
    public Result<Void> importDocument() {
        // TODO: 上传 .md / .txt 文档，读取正文入库
        throw new BizException(501, "接口尚未实现");
    }

    @GetMapping("/{id}/export")
    public Result<Void> exportSingle(@PathVariable String id) {
        // TODO: 将单条记录另存导出为 .md 或 .txt
        throw new BizException(501, "接口尚未实现");
    }
}
