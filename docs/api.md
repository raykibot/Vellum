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
- 在 [WebConfig.java](file:///d:/Code/code_self/vellum-server/src/main/java/com/vellum/config/WebConfig.java) 中配置拦截器：仅放行 `/api/v1/auth/login`，其余 `/api/**` 请求统一由 [JwtInterceptor.java](file:///d:/Code/code_self/vellum-server/src/main/java/com/vellum/common/JwtInterceptor.java) 校验 7 天有效期 JWT。
- **Token 传递方式**：常规接口通过请求头 `Authorization: Bearer <token>` 传递；`<img>` 等无法设置请求头的媒体请求支持通过 Query 参数 `?token=<token>` 传递。
- **失败响应**：缺失、签名无效或过期时，统一返回 HTTP `401` 状态码与 JSON `{ "code": 401, "message": "...", "data": null }`。

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

### 2.1 统一时间线游标分页列表（✅ 已实现）

> **设计定位**：按记录时间倒序游标分页展示，支持类型筛选（`ALL` / `MOMENT` / `ARTICLE`）。短动态直接返回完整正文；长文仅返回去除了重复标题头的前 140 字摘要并标记 `contentTruncated = true`，点击进入详情时再按需加载完整正文，大幅节省首屏带宽。

- **接口路径**：`GET /api/v1/posts`
- **是否鉴权**：是（需携带 `Authorization: Bearer <token>`）
- **关联代码**：
  - [PostController.java](file:///d:/Code/code_self/vellum-server/src/main/java/com/vellum/controller/PostController.java)
  - [PostService.java](file:///d:/Code/code_self/vellum-server/src/main/java/com/vellum/service/PostService.java)
  - [PostMapper.java](file:///d:/Code/code_self/vellum-server/src/main/java/com/vellum/mapper/PostMapper.java) / [PostMapper.xml](file:///d:/Code/code_self/vellum-server/src/main/resources/mapper/PostMapper.xml)
  - [CursorPageResult.java](file:///d:/Code/code_self/vellum-server/src/main/java/com/vellum/dto/CursorPageResult.java) / [PostItem.java](file:///d:/Code/code_self/vellum-server/src/main/java/com/vellum/dto/PostItem.java)

#### 请求参数（Query String）

| 参数 | 类型 | 必填 | 默认值 | 说明 |
| :--- | :--- | :---: | :---: | :--- |
| `size` | `int` | 否 | `12` | 每批条数（限制在 `1 ~ 50` 之间；Web 端按左栏高度动态计算铺满 + 2 条缓冲） |
| `type` | `string` | 否 | `ALL` | 可选 `ALL` / `MOMENT` / `ARTICLE`（忽略大小写） |
| `cursorTime` | `string` | 否 | `null` | 上一批返回的 `nextCursorTime`（ISO-8601 UTC 字符串，需与 `cursorId` 成对传入） |
| `cursorId` | `string` | 否 | `null` | 上一批返回的 `nextCursorId`（UUID，与 `cursorTime` 共同消除同秒记录漂移） |

**请求示例**：
- 首屏首批：`GET /api/v1/posts?size=11`
- 加载下一批：`GET /api/v1/posts?size=11&cursorTime=2026-11-21T14:10:00Z&cursorId=00000000-0000-0000-0000-000000000102`

#### 响应结构（`Result<CursorPageResult<PostItem>>`）

| 字段 | 类型 | 说明 |
| :--- | :--- | :--- |
| `size` | `int` | 本次请求的批次上限 |
| `hasMore` | `boolean` | 是否还有更早的记录（由后端多查 1 条判断，无需 `SELECT COUNT(*)`） |
| `nextCursorTime` | `string \| null` | 下一批游标时间戳；`hasMore = false` 时为 `null` |
| `nextCursorId` | `string \| null` | 下一批游标记录 ID；`hasMore = false` 时为 `null` |
| `items` | `array` | 当前批时间线条目列表 |

**`PostItem` 字段说明**：

| 字段 | 类型 | 说明 |
| :--- | :--- | :--- |
| `id` | `string` | 动态 / 长文 UUID |
| `type` | `string` | `MOMENT`（随手动态）/ `ARTICLE`（长文） |
| `title` | `string \| null` | 标题（短动态为 `null`，长文有值） |
| `content` | `string` | 短动态为完整正文；长文在列表中为前 140 字摘要，在详情接口为完整正文 |
| `locationCity` | `string \| null` | 城市名（如 `"杭州市"`），未定位或失败时为 `null` |
| `recordTime` | `string` | 记录发生时间（排序主轴） |
| `createdAt` | `string` | 创建时间 |
| `updatedAt` | `string` | 更新时间 |
| `images` | `array` | 关联图片相对路径列表（按 `sortOrder` 排序，如 `["/api/v1/files/<id>"]`；无图为空数组 `[]`） |
| `contentTruncated` | `boolean` | 正文是否被截断（长文列表超长或去除了重复开头标题时为 `true`；详情与短动态固定 `false`） |

```json
{
  "code": 0,
  "message": "ok",
  "data": {
    "size": 11,
    "hasMore": true,
    "nextCursorTime": "2026-11-21T14:10:00Z",
    "nextCursorId": "00000000-0000-0000-0000-000000000102",
    "items": [
      {
        "id": "00000000-0000-0000-0000-000000000202",
        "type": "ARTICLE",
        "title": "小怪兽的孤独守恒定律",
        "content": "凌晨一点的二十四小时便利店，总是孤单得像漂在黑海中央的太空站...",
        "locationCity": "杭州市",
        "recordTime": "2026-11-21T17:15:00Z",
        "createdAt": "2026-11-23T06:55:00Z",
        "updatedAt": "2026-11-23T06:55:00Z",
        "images": [],
        "contentTruncated": true
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
        "images": [
          "/api/v1/files/6c8a2f41-9d3b-4e12-b84f-72e5c9103a18"
        ],
        "contentTruncated": false
      }
    ]
  }
}
```

#### 内部执行逻辑与 SQL（简单 SQL 用注解，复杂/动态 SQL 写 XML，不使用 `LambdaQueryWrapper`）
1. **Controller 层**：接收 `size`（默认 `12`）、`type`、`cursorTime`、`cursorId`，在 `try/catch` 中调用 `postService.list(size, type, cursorTime, cursorId)`；捕获 `BizException` 打 `log.warn` 并透传错误码，捕获其他 `Exception` 打 `log.error` 并返回 `Result.fail(500, "查询失败")`。
2. **参数校验**：在 `PostService` 中限制 `safeSize` 在 `1 ~ 50`，校验 `type`（`ALL`/`MOMENT`/`ARTICLE`）及游标 `cursorTime` 与 `cursorId` 必须成对传入。
3. **单表游标查询主记录（多查 1 条判 `hasMore`）**：调用 [PostMapper.xml](file:///d:/Code/code_self/vellum-server/src/main/resources/mapper/PostMapper.xml) 的 `selectCursorPage(..., limit = safeSize + 1)`：
   ```sql
   SELECT id, type, title, content, location_city, record_time, deleted, created_at, updated_at
   FROM post
   WHERE deleted = FALSE
     [AND type = #{type}]
     [AND (record_time, id) < (#{cursorTime}, #{cursorId})]
   ORDER BY record_time DESC, id DESC
   LIMIT #{limit}
   ```
   若返回行数 `> safeSize`，说明仍有下一页（`hasMore = true`），截取前 `safeSize` 条并取最后一条的 `(record_time, id)` 作为下一次游标，完全省掉全表 `COUNT(*)`。
4. **批量单表查图与摘要组装**：提取本批 `postIds`，通过 [PostImageMapper.xml](file:///d:/Code/code_self/vellum-server/src/main/resources/mapper/PostImageMapper.xml) 批量单表查询 `post_image`；长文裁剪为 140 字摘要并标记 `contentTruncated`，短动态保留原文。

---

### 2.2 单条记录详情（✅ 已实现）

- **接口路径**：`GET /api/v1/posts/{id}`
- **设计定位**：列表对长文仅返回摘要时，前端点击长文卡片后按需请求完整 Markdown 正文与关联图片（并通过前端缓存复用，不重复拉取）。
- **执行逻辑**：
  1. 校验 `id` 非空白（空白抛 `400`），调用 `PostMapper.selectActiveById(id)` 单表查 `post`；不存在或已删除抛出 `BizException(404, "记录不存在")`。
  2. 调用 `PostImageMapper.selectByPostId(id)` 单表按 `sort_order ASC` 查询关联图片并映射为 `/api/v1/files/{id}`。
  3. 组装返回完整 `PostItem`（`content` 为完整正文，`contentTruncated = false`）。

---

### 2.3 发布动态 / 长文（✅ 已实现）

- **接口路径**：`POST /api/v1/posts`
- **是否鉴权**：是（需携带 `Authorization: Bearer <token>`）
- **关联代码**：
  - [PostController.java](file:///d:/Code/code_self/vellum-server/src/main/java/com/vellum/controller/PostController.java)
  - [PostService.java](file:///d:/Code/code_self/vellum-server/src/main/java/com/vellum/service/PostService.java)
  - [PostMapper.java](file:///d:/Code/code_self/vellum-server/src/main/java/com/vellum/mapper/PostMapper.java)
  - [CreatePostRequest.java](file:///d:/Code/code_self/vellum-server/src/main/java/com/vellum/dto/CreatePostRequest.java)

#### 请求体（`application/json` · `CreatePostRequest`）

| 字段 | 类型 | 必填 | 校验与默认值 | 说明 |
| :--- | :--- | :---: | :--- | :--- |
| `content` | `string` | 否 | 仅 `MOMENT` 支持纯图无文字（存 `""`）；`ARTICLE` 必填正文 | 正文内容（纯文本或 Markdown；支持纯图动态不填文字） |
| `title` | `string` | 否 | `@Size(max = 200)`；空白串转 `null` | 标题（随手动态可不填） |
| `type` | `string` | 否 | 仅允许 `MOMENT` / `ARTICLE`（忽略大小写）；非法值抛 `400` | 不传时由后端自动推断：有非空标题则为 `ARTICLE`，否则为 `MOMENT` |
| `locationCity` | `string` | 否 | `@Size(max = 64)`；空白串转 `null` | 仅存城市名（如 `"杭州市"`），定位失败或未选传 `null` |
| `recordTime` | `string` | 否 | ISO-8601 UTC 时间；不传取当前 UTC 时间 | 记录发生时间（支持补记或 Android 断网补发时保留原记录时间） |
| `imageIds` | `array<string>` | 否 | `@Size(max = 9)`；去重保留顺序 | 通过 `/api/v1/files/upload` 上传后拿到的图片 ID 列表（最多 9 张） |

```json
{
  "type": "MOMENT",
  "title": null,
  "content": "下班路上买了一杯热美式，杭州终于有点初冬的感觉了。",
  "locationCity": "杭州市",
  "recordTime": "2026-11-23T07:35:00Z",
  "imageIds": [
    "6c8a2f41-9d3b-4e12-b84f-72e5c9103a18"
  ]
}
```

#### 响应结构（`Result<PostItem>`）
直接复用 `PostItem` 返回新创建的记录详情：

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
    "images": [
      "/api/v1/files/6c8a2f41-9d3b-4e12-b84f-72e5c9103a18"
    ],
    "contentTruncated": false
  }
}
```

#### 内部执行逻辑与 SQL（简单 SQL 用注解，不使用 `LambdaQueryWrapper`）
1. **Controller 层**：打印 `log.info("发布动态")`，接收 `@Valid @RequestBody CreatePostRequest`（校验 `title <= 200`、`locationCity <= 64`、`imageIds.size <= 9`），在 `try/catch` 中调用 `postService.create(request)`；捕获 `BizException` 打 `log.warn` 并返回错误码，捕获其他 `Exception` 打 `log.error` 并返回 `Result.fail(500, "发布失败")`（日志不打印正文内容）。
2. **字段清洗与校验**：在 `PostService.create`（标注 `@Transactional(rollbackFor = Exception.class)`）中处理：
   - `title`、`locationCity` 为空或纯空白串时统一转为 `null`；`content` 为空或空白串时转为 `""`；
   - `imageIds` 去空白、保序去重，超过 9 张抛 `BizException(400)`；
   - `type`：不传时按 `title != null ? "ARTICLE" : "MOMENT"` 自动推断；传入时转大写并校验必须为 `MOMENT` 或 `ARTICLE`，否则抛 `BizException(400, "不支持的内容类型")`；`ARTICLE` 正文为空抛 `400`，`MOMENT` 正文与 `imageIds` 同时为空抛 `400`；
   - `recordTime`：为空时取当前 UTC 时间 `now`，同时赋值 `deleted = false`、`createdAt = now`、`updatedAt = now`；
   - 生成主键：`UUID.randomUUID().toString()`。
3. **单表插入与事务绑定图片**：
   - 调用 `PostMapper.insertPost(post)`（`@Insert` 注解）；
   - 若存在 `imageIds`，按数组顺序直接循环调用 `PostImageMapper.bindToPost(imageId, postId, sortOrder)`（SQL 条件含 `deleted = FALSE AND post_id IS NULL`）；任何一张受影响行数不为 `1` 时抛出 `BizException(400)` 触发事务整体回滚。
4. **返回结果**：将已插入的 `Post` 与对应 `/api/v1/files/{id}` 图片地址列表组装为 `PostItem` 返回给前端。

---

### 2.4 删除动态 / 长文（✅ 已实现）

- **接口路径**：`DELETE /api/v1/posts/{id}`
- **是否鉴权**：是（需携带 `Authorization: Bearer <token>`）
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

---

## 3. 图片文件模块（`FileController`）

### 3.1 上传图片（✅ 已实现）

- **接口路径**：`POST /api/v1/files/upload`
- **请求类型**：`multipart/form-data`（字段名 `file`，支持 `image/jpeg`、`image/png`、`image/webp`，单张 `<= 20MB`）
- **关联代码**：
  - [FileController.java](file:///d:/Code/code_self/vellum-server/src/main/java/com/vellum/controller/FileController.java)
  - [FileService.java](file:///d:/Code/code_self/vellum-server/src/main/java/com/vellum/service/FileService.java)
  - [PostImageMapper.java](file:///d:/Code/code_self/vellum-server/src/main/java/com/vellum/mapper/PostImageMapper.java)
  - [UploadFileResponse.java](file:///d:/Code/code_self/vellum-server/src/main/java/com/vellum/dto/UploadFileResponse.java)

#### 响应示例（成功 `code = 0`）

```json
{
  "code": 0,
  "message": "ok",
  "data": {
    "id": "6c8a2f41-9d3b-4e12-b84f-72e5c9103a18",
    "url": "/api/v1/files/6c8a2f41-9d3b-4e12-b84f-72e5c9103a18"
  }
}
```

#### 内部执行逻辑与一致性设计
1. **格式校验与内存压缩**：
   - 校验文件非空、体积 `<= 20MB`，依据文件名后缀（`.jpg` / `.jpeg` / `.jfif` / `.png` / `.webp`）及常见图片 `Content-Type` 识别格式；
   - JPEG 与 PNG 使用 `Thumbnailator` 在内存压缩：长边超过 `1920px` 时等比限宽至 `1920px`（不强行放大原小图），自动识别 EXIF 方向摆正；JPEG 压缩质量 `0.82`，PNG 保留透明通道，WebP 原样直存。
2. **MinIO 上传与异常补偿**：
   - 每次上传自动检查并按需创建私有 Bucket（`createBucket`），使用 `ByteArrayInputStream` 调用 `putObject` 存入 `yyyy/MM/<uuid>.<ext>`；
   - 写入 `post_image`（初始 `post_id = NULL`）若发生异常，立即 `removeObject` 回滚清理对象，避免将慢网络 IO 包入数据库长事务。

---

### 3.2 流式读取图片（✅ 已实现）

- **接口路径**：`GET /api/v1/files/{id}`
- **是否鉴权**：是（支持 `Authorization: Bearer <token>` 或 Query 参数 `?token=<token>`）
- **响应形式**：直接返回二进制图片流（供 `<img>` 原生渲染），不包裹 JSON。
- **缓存协商与状态码**：
  - 优先查询 `post_image` 有效元数据（不存在或已删除直接返回 `404 Not Found`）；
  - 请求头 `If-None-Match` 命中图片 UUID 时直接返回 `304 Not Modified`（不读取 MinIO）；
  - 命中图片时流式返回字节内容，并附带 `ETag: "<id>"` 与 `Cache-Control: private, max-age=31536000, immutable`。
