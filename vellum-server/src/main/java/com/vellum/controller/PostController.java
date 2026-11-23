package com.vellum.controller;

import com.vellum.common.BizException;
import com.vellum.common.Result;
import com.vellum.dto.CreatePostRequest;
import com.vellum.dto.PageResult;
import com.vellum.dto.PostItem;
import com.vellum.service.PostService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

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
    public Result<PageResult<PostItem>> list(
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(defaultValue = "5") int size) {
        log.info("首页数据返回");
        try {
            return Result.ok(postService.list(page, size));
        } catch (BizException e) {
            log.warn("分页查询时间流失败, page={}, size={}, code={}, message={}",
                    page, size, e.getCode(), e.getMessage(), e);
            return Result.fail(e.getCode(), e.getMessage());
        } catch (Exception e) {
            log.error("分页查询时间流异常, page={}, size={}", page, size, e);
            return Result.fail(500, "查询失败");
        }
    }

    @GetMapping("/{id}")
    public Result<Void> detail(@PathVariable String id) {
        // TODO: 查询单条动态或长文详情（含关联图片）
        throw new BizException(501, "接口尚未实现");
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
