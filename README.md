# 素笺（Vellum）

个人私有生活记录与 AI 状态分析软件。支持随手动态、长文（Markdown / TXT 导入与另存）、照片压缩存 MinIO、城市级定位，以及按时间段导出 `.md` / 含图 `.zip` 给 AI 分析。

## 目录结构

```text
vellum/
├── docs/            # 产品需求文档 (prd.md) 与技术设计文档 (tech_design.md)
├── deploy/          # 本地 Docker Compose (PostgreSQL + MinIO) 与环境变量模板
├── vellum-server/   # Java 17 + Maven + Spring Boot 3.4 极简 MVC 后端
├── vellum-web/      # React Web 端（待搭建）
└── vellum-app/      # Flutter Android 端（待搭建）
```

## 本地快速启动

1. 复制环境变量模板：
   ```bash
   cp deploy/.env.example deploy/.env
   ```
2. 一键启动 PostgreSQL 与 MinIO（首次启动会自动执行 `schema.sql` 建表）：
   ```bash
   docker compose -f deploy/docker-compose.yml --env-file deploy/.env up -d
   ```
   - PostgreSQL：`localhost:5432`
   - MinIO API：`http://localhost:9000`
   - MinIO 控制台：`http://localhost:9001`
3. 编译后端工程：
   ```bash
   mvn -f vellum-server/pom.xml test-compile
   ```
