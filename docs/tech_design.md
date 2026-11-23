# 技术架构与工程规范设计 — 素笺（Vellum）

> **项目名称**：素笺（**Vellum**）  
> **文档版本**：v3.0（极简定稿版）  
> **核心原则**：**够用就好、拒绝过度设计、代码简洁高可读、业务逻辑用 Java 代码处理、SQL 保持单表极简、库表严禁物理外键**

---

## 1. 整体技术栈

### 1.1 后端服务（`vellum-server`）

| 维度 | 选型 | 理由与取舍 |
| :--- | :--- | :--- |
| **语言与构建** | **Java 17 + Maven** | 匹配本机 JDK 17 与 Maven 3.6.3，使用 `record` 编写精简 DTO |
| **核心框架** | **Spring Boot 3.4.13（经典 MVC）** | `Controller → Service → Mapper` 清晰直观，无多余分层 |
| **数据库** | **PostgreSQL 16** | 所有动态、长文及导入的 `.md`/`.txt` 正文统一存 `TEXT` 字段，查询与导出极简 |
| **ORM** | **MyBatis-Plus 3.5.18** | 简单单表 SQL 使用 MyBatis 注解写在函数上，复杂或较长 SQL 写入 Mapper XML，不使用 `LambdaQueryWrapper` |
| **建表方式** | **普通 SQL 脚本（`schema.sql`）** | 暂不引入 Flyway，初期脚本直观执行，后续有需要再接入迁移工具 |
| **图片对象存储** | **MinIO（`io.minio:minio:8.5.17`）** | 成熟标准对象存储，本地 Docker 一键起带控制台；后续可无缝切换兼容 S3 的云存储 |
| **图片压缩** | **Thumbnailator 0.4.21** | 简单压缩后直接存入 MinIO，省空间省流量 |
| **登录鉴权** | **JJWT 0.13.0 + 轻量 `JwtInterceptor` + `spring-security-crypto`（BCrypt）** | 单人自用不引入笨重的 Spring Security 全家桶、Redis 和 Refresh Token 表；签发 **7 天有效期 JWT**，配合 HTTPS 加密传输 |
| **导出打包** | Java 原生 `ZipOutputStream` | 按时间查库拼装 Markdown，从 MinIO 拉取关联图片打包 `.zip` 或直接输出 `.md` |

### 1.2 Web 端（`vellum-web`）
- **React 19 + TypeScript + Vite + pnpm**
- **Tailwind CSS v4 + shadcn/ui + Lucide Icons**（极简留白高级审美）
- **React Router + Axios + `react-markdown`**

### 1.3 Android 端（`vellum-app`）
- **Flutter（Dart 3 + Impeller 引擎）**：追求 60/120fps 极简流畅界面与高审美动效
- **本地离线**：`Drift`（SQLite）缓存历史列表并暂存断网待发动态；恢复网络后直接调用后端**普通发布接口（`POST /api/v1/posts`）**补发，**后端零额外同步接口**
- **系统能力**：`local_auth`（指纹解锁）、系统相册选图 + 端侧压缩、`geolocator`（粗略定位 + 本地全国地级市坐标表 0 元离线解析市名，失败即置空）

---

## 2. 项目目录结构（Monorepo）

```text
vellum/
├── docs/                                # 产品与技术文档
│   ├── prd.md
│   └── tech_design.md
├── deploy/                              # 本地容器与部署配置
│   ├── docker-compose.yml               # PostgreSQL 16 + MinIO
│   └── .env.example
├── vellum-server/                       # Java 17 + Maven 后端服务
├── vellum-web/                          # React Web 端（后续搭建）
└── vellum-app/                          # Flutter Android 端（后续搭建）
```

### 后端极简 MVC 包结构（`vellum-server`）

仅保留必要目录与类，拒绝冗余配置和无意义接口壳子：

```text
vellum-server/
├── pom.xml
└── src/
    ├── main/
    │   ├── java/com/vellum/
    │   │   ├── VellumApplication.java       # 启动类
    │   │   ├── config/
    │   │   │   ├── WebConfig.java           # CORS 跨域 + 注册 JWT 拦截器
    │   │   │   └── MinioConfig.java         # 初始化 MinioClient
    │   │   ├── common/
    │   │   │   ├── Result.java              # 统一返回结构
    │   │   │   ├── BizException.java        # 业务异常
    │   │   │   ├── GlobalExceptionHandler.java
    │   │   │   └── JwtInterceptor.java      # 轻量 JWT（7天）请求拦截器
    │   │   ├── controller/
    │   │   │   ├── AuthController.java      # 登录、改密
    │   │   │   ├── PostController.java      # 动态/长文 CRUD + 上传/导出 md、txt
    │   │   │   ├── FileController.java      # 图片上传至 MinIO + 读取/获取地址
    │   │   │   └── ExportController.java    # 按时间段导出 md / 含图 zip
    │   │   ├── service/
    │   │   │   ├── AuthService.java
    │   │   │   ├── PostService.java
    │   │   │   ├── FileService.java
    │   │   │   └── ExportService.java
    │   │   ├── mapper/
    │   │   │   ├── SysUserMapper.java
    │   │   │   ├── PostMapper.java
    │   │   │   └── PostImageMapper.java
    │   │   └── entity/
    │   │       ├── SysUser.java
    │   │       ├── Post.java
    │   │       └── PostImage.java
    │   └── resources/
    │       ├── application.yml              # 精简单配置文件（支持环境变量覆盖）
    │       └── sql/
    │           └── schema.sql               # 普通建表 SQL 脚本（无外键）
    └── test/
```

---

## 3. 极简库表结构（PostgreSQL · 3 张表 · 零外键）

> **硬性约束**：严禁物理外键，表间仅做逻辑关联；所有正文统一存 PostgreSQL `TEXT`，图片统一存 MinIO；单表查询后用 Java 代码内存组装。

### ① `sys_user`（用户表 · 4 字段）

| 字段 | 类型 | 约束 | 说明 |
| :--- | :--- | :--- | :--- |
| `id` | `VARCHAR(36)` | PK | UUID |
| `username` | `VARCHAR(64)` | UNIQUE, NOT NULL | 登录账号 |
| `password_hash` | `VARCHAR(128)` | NOT NULL | BCrypt 密码哈希 |
| `created_at` | `TIMESTAMPTZ` | NOT NULL | 创建时间 |

### ② `post`（动态 / 长文统一主表 · 9 字段）

| 字段 | 类型 | 约束 | 说明 |
| :--- | :--- | :--- | :--- |
| `id` | `VARCHAR(36)` | PK | UUID |
| `type` | `VARCHAR(16)` | NOT NULL | `MOMENT`（短动态）/ `ARTICLE`（长文） |
| `title` | `VARCHAR(200)` | NULL | 标题（短动态为空；长文/导入文档有值） |
| `content` | `TEXT` | NOT NULL | 正文（纯文本或 Markdown；导入的 `.md`/`.txt` 直接存此字段） |
| `location_city` | `VARCHAR(64)` | NULL | **仅存城市名**（如 `杭州市`），定位失败或未选为 `NULL` |
| `record_time` | `TIMESTAMPTZ` | NOT NULL | 记录时间（支持补记，时间流与导出排序基准） |
| `deleted` | `BOOLEAN` | NOT NULL DEFAULT false | 逻辑删除标记 |
| `created_at` | `TIMESTAMPTZ` | NOT NULL | 创建时间 |
| `updated_at` | `TIMESTAMPTZ` | NOT NULL | 更新时间 |

> **索引**：`idx_post_record_time (record_time DESC)`、`idx_post_city (location_city)`。

### ③ `post_image`（图片逻辑关联表 · 6 字段）

| 字段 | 类型 | 约束 | 说明 |
| :--- | :--- | :--- | :--- |
| `id` | `VARCHAR(36)` | PK | UUID |
| `post_id` | `VARCHAR(36)` | NULL | 逻辑关联 `post.id`（无外键；支持先传图后绑定动态） |
| `object_name` | `VARCHAR(255)` | NOT NULL | MinIO 对象路径（如 `2026/11/<uuid>.jpg`） |
| `sort_order` | `SMALLINT` | NOT NULL DEFAULT 0 | 图片顺序 |
| `deleted` | `BOOLEAN` | NOT NULL DEFAULT false | 逻辑删除标记 |
| `created_at` | `TIMESTAMPTZ` | NOT NULL | 上传时间 |

> **索引**：`idx_post_image_post_id (post_id)`。

---

## 4. 数据交互与代码风格约定

1. **接口规范**：
   - RESTful 风格，统一前缀 `/api/v1/`；常规 `page / size` 分页；
   - JSON 字段 `camelCase`，数据库字段 `snake_case`；时间统一 ISO-8601 UTC 字符串；
   - 统一响应：`{ code, message, data }`（`code = 0` 成功，其余为清晰错误码与提示）。
2. **Java 编码风格**：
   - **极简可读**：Controller 只接参数与返回结果；业务规则与数据组装集中在 Service 用清晰的 Java 代码完成；Mapper 仅做单表简单查询，不写复杂 JOIN；
   - **按需抽象**：不为单一实现强写 `IXxxService` 接口；配置项用 `@Value` 直读，避免过度包装；
   - **DTO**：后续实现接口时按需用 Java 17 `record` 编写，保持简洁不可变；
   - **日志安全**：不打印密码、JWT Token 与用户正文内容。
