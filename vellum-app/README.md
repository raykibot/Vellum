# 素笺 Vellum · Android 端 (`vellum-app`)

基于 Figma 设计稿（390×844 极简纸感排版）还原的 Flutter Android 客户端，支持：
- 首页统一时间流（按月分组、全部/动态/长文切换、关键词与日期筛选）
- 动态与长文详情（杂志感 Markdown 排版、全屏缩放画廊、单条另存 `.md`/`.txt`、逻辑删除）
- 发布动态/长文（最多 9 张本地压缩图片、导入 `.md`/`.txt`、离线城市定位、断网 SQLite 队列自动补发）
- AI 阶段导出（近 7 天 / 近 30 天 / 自定义区间，`.zip` / `.md` 一键导出并分享）
- 指纹解锁与切后台自动锁屏（`local_auth` + `FlutterFragmentActivity`）
- 浅色/深色/跟随系统主题、动态服务地址配置、以及登录页「预览示例界面」离线体验模式

## 本地运行指南（Windows）

1. **准备环境**（本仓库尚未包含 Flutter / Android SDK）：
   - 安装 Flutter SDK（>= 3.24，Dart >= 3.5）并加入 `PATH`
   - 安装 Android Studio 与 Android SDK（API 35）
   - 执行 `flutter doctor` 确认 Android 工具链就绪
2. **补全 Gradle Wrapper（首次运行前）**：
   ```powershell
   cd d:\Code\code_self\vellum-app
   flutter create --platforms=android .
   ```
   > 若提示覆盖已有文件，请保留当前已配置好的 `AndroidManifest.xml`、`MainActivity.kt`（继承 `FlutterFragmentActivity`）与 `network_security_config.xml`。
3. **拉取依赖并运行**：
   ```powershell
   flutter pub get
   flutter test
   flutter run
   ```
