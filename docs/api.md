# 接口设计与联调文档 — 素笺（Vellum）

> **基础路径**：`/api/v1`  
> **接口风格**：RESTful JSON（`camelCase` 字段），时间统一 ISO-8601 UTC 字符串（例如 `2026-11-23T07:00:00Z`）  
> **状态说明**：本文档记录当前已完成接口的实现细节（便于 Code Review）与待确认接口的设计方案。

---

## 0. 全局通用约定

### 0.1 统一响应体 `Result<T>`
所有接口均返回统一的 JSON 包装结构（见 [Result.java](file:///d:/Code/code_self/vellum-server/src/main/java/com/vellum/common/Result.java)）：

```json
{
  "code": 0,
  "message": "ok",
  "data": {}
}
```

| 状态码 `code` | 含义 | 说明 |
| :---: | :--- | :--- |
| `0` | 成功 | 正常返回业务数据 |
| `400` | 参数校验失败 | `@Valid` 触发，由 `GlobalExceptionHandler` 拼接错误字段提示返回 |
| `401` | 认证失败 | 用户名或密码错误 / JWT 无效或过期 |
| `404` | 资源不存在 | 查询指定记录不存在（规划中） |
| `500` | 服务器内部错误 | 未捕获异常兜底返回 |
| `501` | 接口尚未实现 | 骨架占位接口默认抛出 |

### 0.2 鉴权拦截规则
- 在 [WebConfig.java](file:///d:/Code/code_self/vellum-server/src/main/java/com/vellum/config/WebConfig.java) 中配置了拦截器规则：放行 `/api/v1/auth/login`，其余 `/api/**` 请求均会经过 [JwtInterceptor.java](file:///d:/Code/code_self/vellum-server/src/main/java/com/vellum/common/JwtInterceptor.java)。
- **当前状态**：`JwtInterceptor` 仍处于骨架阶段（暂直接 `return true` 放行），待完成 `Bearer <token>` 校验逻辑后生效。

---

## 1. 认证模块（`AuthController`）

### 1.1 用户登录（✅ 已实现）

- **接口路径**：`POST /api/v1/auth/login`
- **是否鉴权**：否（白名单放行）
- **关联代码**：
  - [AuthController.java](file:///d:/Code/code_self/vellum-server/src/main/java/com/vellum/controller/AuthController.java)
  - [AuthService.java](file:///d:/Code/code_self/vellum-server/src/main/java/com/vellum/service/AuthService.java)
  - [SysUserMapper.java](file:///d:/Code/code_self/vellum-server/src/main/java/com/vellum/mapper/SysUserMapper.java)
  - [LoginRequest.java](file:///d:/Code/code_self/vellum-server/src/main/java/com/vellum/dto/LoginRequest.java) / [LoginResponse.java](file:///d:/Code/code_self/vellum-server/src/main/java/com/vellum/dto/LoginResponse.java)

#### 请求体（`application/json`）

| 字段 | 类型 | 必填 | 校验规则 | 说明 |
| :--- | :--- | :---: | :--- | :--- |
| `username` | `string` | 是 | `@NotBlank`（`"用户名不能为空"`） | 登录账号（如默认测试账号 `Luojiakeng`） |
| `password` | `string` | 是 | `@NotBlank`（`"密码不能为空"`） | 登录明文密码（服务端用 BCrypt 校验） |

```json
{
  "username": "Luojiakeng",
  "password": "******"
}
```

#### 响应示例（成功 `code = 0`）

| 字段 | 类型 | 说明 |
| :--- | :--- | :--- |
| `token` | `string` | HS256 签名的 JWT 字符串（有效期 7 天） |
| `expiresAt` | `string` | Token 过期时间（UTC 时间戳） |

```json
{
  "code": 0,
  "message": "ok",
  "data": {
    "token": "eyJhbGciOiJIUzI1NiJ9...",
    "expiresAt": "2026-11-30T07:00:00Z"
  }
}
```

#### 内部执行逻辑与 SQL（供 Review）
1. **Controller 层**：进入方法先打印 `log.info("登录")`，随后在 `try/catch` 内调用 `authService.login(request)`：
   - 捕获 `BizException`：打印 `log.warn`（记录 `username`、`code`、`message` 及异常栈，不打印密码），返回 `Result.fail(e.getCode(), e.getMessage())`。
   - 捕获其他 `Exception`：打印 `log.error`（记录 `username` 与异常栈），返回 `Result.fail(1, "fail")`。
   - 若 `@Valid` 入参校验不通过，直接由 `GlobalExceptionHandler` 拦截返回 `{ code: 400, message: "...", data: null }`。
2. **Service & Mapper 层**：
   - 对 `request.username().trim()` 调用 MyBatis `@Select` 注解 SQL（无 XML）：
     ```sql
     SELECT id, username, password_hash, created_at FROM sys_user WHERE username = #{username} LIMIT 1
     ```
   - 校验用户非空且 `BCryptPasswordEncoder.matches(request.password(), user.getPasswordHash())` 为真；否则抛出 `BizException(401, "用户名或密码错误")`。
   - 使用 `vellum.jwt.secret` 与 `vellum.jwt.expire-days`（默认 `7` 天），通过 JJWT 签发令牌：`sub = user.getId()`、`claim("username", user.getUsername())`、`iat` 与 `exp = now + 7天`。

---

### 1.2 修改密码（⏸️ 暂未实现 · 501 占位）

- **接口路径**：`PUT /api/v1/auth/password`
- **当前状态**：骨架占位，调用固定抛出 `BizException(501, "接口尚未实现")`。

---

## 2. 动态与长文模块（`PostController`）

### 2.1 统一时间线分页列表（✅ 已实现）

> **设计定位**：进入软件后首页默认按时间线统一倒序展示全部记录，**现阶段不区分动态（`MOMENT`）与长文（`ARTICLE`），也暂不做关键词/日期/城市筛选**。

- **接口路径**：`GET /api/v1/posts`
- **是否鉴权**：是（需携带 `Authorization: Bearer <token>`；当前 `JwtInterceptor` 处于骨架放行状态）
- **关联代码**：
  - [PostController.java](file:///d:/Code/code_self/vellum-server/src/main/java/com/vellum/controller/PostController.java)
  - [PostService.java](file:///d:/Code/code_self/vellum-server/src/main/java/com/vellum/service/PostService.java)
  - [PostMapper.java](file:///d:/Code/code_self/vellum-server/src/main/java/com/vellum/mapper/PostMapper.java)
  - [PageResult.java](file:///d:/Code/code_self/vellum-server/src/main/java/com/vellum/dto/PageResult.java) / [PostItem.java](file:///d:/Code/code_self/vellum-server/src/main/java/com/vellum/dto/PostItem.java)

#### 请求参数（Query String）

| 参数 | 类型 | 必填 | 默认值 | 说明 |
| :--- | :--- | :---: | :---: | :--- |
| `page` | `int` | 否 | `1` | 页码（从 `1` 开始，传入 `< 1` 时代码兜底按 `1` 处理） |
| `size` | `int` | 否 | `5` | 每页条数（代码限制在 `1 ~ 50` 之间，单页默认返回 5 条完整正文） |

**请求示例**：`GET /api/v1/posts?page=1&size=5`

#### 响应结构（`Result<PageResult<PostItem>>`）

| 字段 | 类型 | 说明 |
| :--- | :--- | :--- |
| `page` | `int` | 当前页码 |
| `size` | `int` | 每页条数 |
| `total` | `long` | 总记录数（`post` 表总行数） |
| `items` | `array` | 当前页的时间线条目列表 |

**`PostItem` 字段说明**：

| 字段 | 类型 | 说明 |
| :--- | :--- | :--- |
| `id` | `string` | 动态 / 长文 UUID |
| `type` | `string` | `MOMENT`（随手动态）/ `ARTICLE`（长文），供前端决定卡片展开或折叠显示 |
| `title` | `string \| null` | 标题（短动态为 `null`，长文有值） |
| `content` | `string` | 完整正文内容（纯文本或 Markdown；由前端决定卡片折叠或全展开） |
| `locationCity` | `string \| null` | 城市名（如 `"杭州市"`），未定位或失败时为 `null` |
| `recordTime` | `string` | 记录发生时间（排序主轴） |
| `createdAt` | `string` | 创建时间 |
| `updatedAt` | `string` | 更新时间 |
| `images` | `array \| null` | 关联图片访问列表；**当前未接通图片读取链接，固定返回 `null`** |

```json
{
  "code": 0,
  "message": "ok",
  "data": {
    "page": 1,
    "size": 5,
    "total": 4,
    "items": [
      {
        "id": "00000000-0000-0000-0000-000000000202",
        "type": "ARTICLE",
        "title": "小怪兽的孤独守恒定律",
        "content": "## 小怪兽的孤独守恒定律\n\n凌晨一点的二十四小时便利店...",
        "locationCity": "杭州市",
        "recordTime": "2026-11-21T17:15:00Z",
        "createdAt": "2026-11-23T06:55:00Z",
        "updatedAt": "2026-11-23T06:55:00Z",
        "images": null
      },
      {
        "id": "00000000-0000-0000-0000-000000000102",
        "type": "MOMENT",
        "title": null,
        "content": "昨晚立下铁血 Flag 今早六点半去晨跑...",
        "locationCity": "上海市",
        "recordTime": "2026-11-21T14:10:00Z",
        "createdAt": "2026-11-23T06:55:00Z",
        "updatedAt": "2026-11-23T06:55:00Z",
        "images": null
      }
    ]
  }
}
```

#### 内部执行逻辑与 SQL（简单 SQL 用注解，复杂/较长 SQL 写 XML，不使用 `LambdaQueryWrapper`）
1. **Controller 层**：接收 `page`（默认 `1`）、`size`（默认 `5`），在 `try/catch` 中调用 `postService.list(page, size)`；捕获 `BizException` 打 `log.warn` 并透传错误码，捕获其他 `Exception` 打 `log.error` 并返回 `Result.fail(500, "查询失败")`。
2. **参数规范化**：在 `PostService` 中处理 `safePage = Math.max(1, page)`、`safeSize = Math.min(50, Math.max(1, size))`，计算 `offset = (safePage - 1) * safeSize`。
3. **查询总数**：调用 `PostMapper.countAll()`（`@Select` 注解）：
   ```sql
   SELECT COUNT(*) FROM post WHERE deleted = FALSE
   ```
   若 `total == 0`，直接返回空的 `PageResult(safePage, safeSize, 0, List.of())`。
4. **单表分页查询主记录**：调用 `PostMapper.selectPage(safeSize, offset)`（`@Select` 注解，加 `id DESC` 作为二级排序保证分页顺序稳定）：
   ```sql
   SELECT id, type, title, content, location_city, record_time, deleted, created_at, updated_at
   FROM post
   WHERE deleted = FALSE
   ORDER BY record_time DESC, id DESC
   LIMIT #{size} OFFSET #{offset}
   ```
5. **Java 内存组装**：将 `Post` 映射为 `PostItem`，返回每条记录的完整 `content`，`images` 字段暂置为 `null`。

---

### 2.2 单条记录详情（📋 规划说明 · 暂不实现或按需同步落盘）

- **接口路径**：`GET /api/v1/posts/{id}`
- **规划定位**：用于直接分享/打开单条详情页刷新最新内容，或后续做“列表只返回摘要、详情返回完整正文”时的按需加载。
- **规划逻辑**：
  1. `PostMapper.selectByPostId(id)` 单表查 `post`；若不存在抛出 `BizException(404, "记录不存在")`。
  2. `PostImageMapper.selectByPostId(id)` 单表查关联图片（按 `sort_order ASC`）。
  3. 组装返回单个 `PostItem`（与 `list` 的单条结构完全一致，前后端共用同一个 DTO）。

---

### 2.3 发布动态 / 长文（✅ 已实现）

- **接口路径**：`POST /api/v1/posts`
- **是否鉴权**：是（需携带 `Authorization: Bearer <token>`；当前 `JwtInterceptor` 处于骨架放行状态）
- **关联代码**：
  - [PostController.java](file:///d:/Code/code_self/vellum-server/src/main/java/com/vellum/controller/PostController.java)
  - [PostService.java](file:///d:/Code/code_self/vellum-server/src/main/java/com/vellum/service/PostService.java)
  - [PostMapper.java](file:///d:/Code/code_self/vellum-server/src/main/java/com/vellum/mapper/PostMapper.java)
  - [CreatePostRequest.java](file:///d:/Code/code_self/vellum-server/src/main/java/com/vellum/dto/CreatePostRequest.java)

#### 请求体（`application/json` · `CreatePostRequest`）

| 字段 | 类型 | 必填 | 校验与默认值 | 说明 |
| :--- | :--- | :---: | :--- | :--- |
| `content` | `string` | 是 | `@NotBlank`（`"正文内容不能为空"`） | 正文内容（纯文本或 Markdown） |
| `title` | `string` | 否 | `@Size(max = 200)`；空白串转 `null` | 标题（随手动态可不填） |
| `type` | `string` | 否 | 仅允许 `MOMENT` / `ARTICLE`（忽略大小写）；非法值抛 `400` | 不传时由后端自动推断：有非空标题则为 `ARTICLE`，否则为 `MOMENT` |
| `locationCity` | `string` | 否 | `@Size(max = 64)`；空白串转 `null` | 仅存城市名（如 `"杭州市"`），定位失败或未选传 `null` |
| `recordTime` | `string` | 否 | ISO-8601 UTC 时间；不传取当前 UTC 时间 | 记录发生时间（支持补记或 Android 断网补发时保留原记录时间） |

> **关于图片绑定**：由于图片上传接口（`FileController` / MinIO）尚未实现，本阶段 `create` 暂不处理 `post_image` 绑定，待图片模块打通后再按需追加可选的 `imageIds` 字段。

```json
{
  "type": "MOMENT",
  "title": null,
  "content": "下班路上买了一杯热美式，杭州终于有点初冬的感觉了。",
  "locationCity": "杭州市",
  "recordTime": "2026-11-23T07:35:00Z"
}
```

#### 响应结构（`Result<PostItem>`）
直接复用 `PostItem` 返回新创建的记录详情（`images` 暂返回 `null`）：

```json
{
  "code": 0,
  "message": "ok",
  "data": {
    "id": "e8d7f6a5-4b3c-4d2e-9f1a-0b1c2d3e4f5a",
    "type": "MOMENT",
    "title": null,
    "content": "下班路上买了一杯热美式，杭州终于有点初冬的感觉了。",
    "locationCity": "杭州市",
    "recordTime": "2026-11-23T07:35:00Z",
    "createdAt": "2026-11-23T07:35:10Z",
    "updatedAt": "2026-11-23T07:35:10Z",
    "images": null
  }
}
```

#### 内部执行逻辑与 SQL（简单 SQL 用注解，不使用 `LambdaQueryWrapper`）
1. **Controller 层**：打印 `log.info("发布动态")`，接收 `@Valid @RequestBody CreatePostRequest`（校验 `content` 非空、`title <= 200`、`locationCity <= 64`），在 `try/catch` 中调用 `postService.create(request)`；捕获 `BizException` 打 `log.warn` 并返回错误码，捕获其他 `Exception` 打 `log.error` 并返回 `Result.fail(500, "发布失败")`（日志不打印正文内容）。
2. **字段清洗与校验**：在 `PostService` 中用 Java 代码处理：
   - `title`、`locationCity` 为空或纯空白串时统一转为 `null`；
   - `type`：不传时按 `title != null ? "ARTICLE" : "MOMENT"` 自动推断；传入时转大写并校验必须为 `MOMENT` 或 `ARTICLE`，否则抛 `BizException(400, "不支持的内容类型")`；
   - `recordTime`：为空时取当前 UTC 时间 `now`，同时赋值 `deleted = false`、`createdAt = now`、`updatedAt = now`；
   - 生成主键：`UUID.randomUUID().toString()`。
3. **单表插入**：调用 `PostMapper.insertPost(post)`（`@Insert` 注解）：
   ```sql
   INSERT INTO post (id, type, title, content, location_city, record_time, deleted, created_at, updated_at)
   VALUES (#{id}, #{type}, #{title}, #{content}, #{locationCity}, #{recordTime}, #{deleted}, #{createdAt}, #{updatedAt})
   ```
4. **返回结果**：将已插入的 `Post` 组装为 `PostItem`（`images = null`）返回给前端，便于前端直接乐观更新或插入时间线顶部。

---

### 2.4 删除动态 / 长文（✅ 已实现）

- **接口路径**：`DELETE /api/v1/posts/{id}`
- **是否鉴权**：是（需携带 `Authorization: Bearer <token>`；当前 `JwtInterceptor` 处于骨架放行状态）
- **关联代码**：
  - [PostController.java](file:///d:/Code/code_self/vellum-server/src/main/java/com/vellum/controller/PostController.java)
  - [PostService.java](file:///d:/Code/code_self/vellum-server/src/main/java/com/vellum/service/PostService.java)
  - [PostMapper.java](file:///d:/Code/code_self/vellum-server/src/main/java/com/vellum/mapper/PostMapper.java)
  - [PostImageMapper.java](file:///d:/Code/code_self/vellum-server/src/main/java/com/vellum/mapper/PostImageMapper.java)

#### 路径参数

| 参数 | 类型 | 必填 | 说明 |
| :--- | :--- | :---: | :--- |
| `id` | `string` | 是 | 要删除的动态 / 长文 UUID |

**请求示例**：`DELETE /api/v1/posts/00000000-0000-0000-0000-000000000101`

#### 响应示例

- **删除成功（`code = 0`）**：
```json
{
  "code": 0,
  "message": "ok",
  "data": null
}
```

- **记录不存在（`code = 404`）**：
```json
{
  "code": 404,
  "message": "记录不存在",
  "data": null
}
```

#### 内部执行逻辑与 SQL（逻辑删除 · `@Update` 注解，无外键、不使用 `LambdaQueryWrapper`）
1. **Controller 层**：打印 `log.info("删除动态, id={}", id)`，在 `try/catch` 中调用 `postService.delete(id)`；捕获 `BizException` 打 `log.warn` 并透传错误码消息，捕获其他 `Exception` 打 `log.error` 并返回 `Result.fail(500, "删除失败")`。
2. **事务与参数校验**：`PostService.delete(id)` 标注 `@Transactional(rollbackFor = Exception.class)`，先校验 `id` 非空白（空白抛 `BizException(400, "记录 ID 不能为空")`）。
3. **逻辑删除主表记录**：调用 `PostMapper.softDeleteById(id, now)`（`@Update` 注解）：
   ```sql
   UPDATE post
   SET deleted = TRUE, updated_at = #{updatedAt}
   WHERE id = #{id} AND deleted = FALSE
   ```
   判断受影响行数：若返回 `0`（记录不存在或已被删除），抛出 `BizException(404, "记录不存在")`。
4. **逻辑删除关联图片记录**：调用 `PostImageMapper.softDeleteByPostId(id)`（`@Update` 注解）：
   ```sql
   UPDATE post_image
   SET deleted = TRUE
   WHERE post_id = #{postId} AND deleted = FALSE
   ```
   > **关于 MinIO 图片文件**：逻辑删除后保留 MinIO 真实文件对象，暂不物理清理（后续若做回收站或定期彻底清理时再删对象）。

---

### 2.5 其他占位接口（⏸️ 暂未实现 · 501 占位）
- `PUT /api/v1/posts/{id}`：编辑动态 / 长文
- `POST /api/v1/posts/import`：导入 `.md` / `.txt` 文档
- `GET /api/v1/posts/{id}/export`：单条导出为 `.md` / `.txt`
