# Markdown Editor

跨平台 Markdown 编辑器，面向 Android 与 Windows，专注于稳定、清晰的 Markdown 写作与预览体验。

> 实时预览 · LaTeX 数学公式 · Mermaid 图表 · PDF / HTML / DOCX 导出 · 本地文件管理

<p align="center">
  <img src="assets/icon/Markdown%20App.png" width="128" alt="Markdown Editor icon" />
</p>

## 功能

- **编辑与预览** — Windows 桌面端左右分栏，Android 移动端使用编辑/预览标签页
- **LaTeX 数学公式** — 支持 `$...$` 行内公式与 `$$...$$` 块级公式实时预览
- **Mermaid 图表** — 支持流程图、时序图、甘特图等 Mermaid 内容预览
- **GFM Markdown** — 支持标题、列表、表格、任务列表、删除线、引用和代码块
- **代码高亮** — 代码块使用等宽字体展示，适合技术文档编写
- **PDF 导出** — 从历史文件菜单导出 A4 PDF，支持多页排版、中文字体、图片和降级提示
- **HTML 导出** — 从历史文件菜单导出 HTML，保留 Markdown 格式；浏览器在线加载 KaTeX 和 Mermaid
- **本地文件管理** — 打开、编辑、保存、另存为 Markdown 文件
- **Android SAF 支持** — 使用系统文件选择器读写外部存储文件，保留原文件访问能力
- **编辑历史** — 自动记录最近编辑的文件，并通过本地缓存支持重启后继续编辑
- **图片与链接** — 通过工具栏快速插入图片地址和链接地址，预览中的网页链接可直接使用系统浏览器打开
- **文件分享** — 分享 Markdown 文件或当前文档内容
- **深色模式** — 跟随系统主题切换

## PDF 导出说明

PDF 导出目前只保留在**历史页面文件的三点菜单**中，编辑页面不提供单独的导出按钮。

导出方式是将 Markdown 重新排版为 A4 PDF，而不是像素级截图，因此 PDF 的分页布局不会与屏幕预览完全一致。

- 中文正文和代码块使用内置中文字体
- 长文档自动分页
- 本地图片和可访问的网络图片会尝试嵌入
- 图片无法读取时保留占位提示并继续导出
- LaTeX 和 Mermaid 以标准文本/源码保留，不依赖 SVG 或 WebView 渲染
- 导出不会自动保存未保存的 Markdown 修改

## HTML 导出说明

HTML 导出目前位于**历史页面文件的三点菜单**中。

- 普通 Markdown 格式由现有 `markdown` 库解析并写入 HTML
- LaTeX 公式和 Mermaid 源码保留在 HTML 中
- 浏览器打开 HTML 时通过 zstatic CDN 加载 KaTeX 和 Mermaid 并自动渲染
- CDN 不可访问时，公式和图表仍显示为原始文本

## DOCX 导出说明

DOCX 导出目前位于**历史页面文件的三点菜单**中。

- 中文正文和代码块使用内置中文字体
- 长文档自动分页
- 本地图片和可访问的网络图片会尝试嵌入
- 图片无法读取时保留占位提示并继续导出
- LaTeX 和 Mermaid 以标准文本/源码保留，不依赖 SVG 或 WebView 渲染
- 导出不会自动保存未保存的 Markdown 修改


## 构建

```bash
# 获取依赖
flutter pub get

# Android APK（按架构分包）
flutter build apk --release --split-per-abi

# Android App Bundle
flutter build appbundle --release

# Windows 可执行文件
flutter build windows --release
```

GitHub Actions 支持自动执行代码分析、测试、Android 构建和 Windows 构建。手动触发工作流并将 `publish_release` 设置为 `true` 后，所有平台产物构建成功时会自动创建 GitHub Release。

## 技术栈

| 类别 | 选用 |
|------|------|
| 框架 | Flutter 3.44 / Dart 3.12 |
| Markdown 预览 | gpt_markdown |
| 数学公式预览 | flutter_math_fork（由 gpt_markdown 使用） |
| Mermaid 预览 | flutter_mermaid |
| PDF 生成 | pdf |
| HTML 生成 | markdown / Dart 文件 API |
| 系统浏览器 | url_launcher |
| 文件操作 | file_picker（桌面）/ SAF MethodChannel（Android） |
| 图片与网络 | Dart HttpClient（PDF 网络图片） |
| 权限 | permission_handler |
| 本地存储 | shared_preferences / path_provider |
| 窗口管理 | window_manager |

## Android 权限

首次访问外部存储文件时，Android 可能需要在系统设置中开启「允许管理所有文件」权限。通过系统文件选择器选择的文件同时使用 Android SAF URI 进行读写，以兼容不同存储提供程序。

## 版本记录

### v1.4.0

- 新增设置页，支持浅色、深色和跟随系统主题
- 支持配置自动保存开关和自动保存间隔
- 新增 WebDAV 云同步，可从本地或云端打开、保存和另存为 Markdown 文件
- 云端文件支持浏览远程根目录、进入子目录、返回上级和选择文件
- 云端另存为默认使用当前文件名，并覆盖当前云端文件保存
- 打开未编辑的云端文件也会记录到历史记录

### v1.3.0

- 新增 HTML 和 DOCX 导出功能，保留普通 Markdown 格式
- HTML 页面通过 zstatic CDN 在浏览器端渲染 LaTeX 和 Mermaid
- 预览界面的网页链接支持点击后调用系统默认浏览器打开
- 新增历史文件菜单中的“导出为 HTML”入口

### v1.2.0

- 新增 PDF 导出功能
- 支持 A4 多页重新排版
- 支持中文 PDF 字体和代码块中文显示
- 支持图片嵌入与资源失败降级
- LaTeX / Mermaid 导出增加明确的降级提示
- 修复 Windows PDF 保存路径返回成功但文件未实际写入的问题
- 修复 Android 网络图片 TLS 握手异常导致 PDF 导出失败的问题
- 优化 Android SAF 文件操作和历史文件访问
- 移除编辑页面导出按钮，仅保留历史页面导出入口
- 新增 GitHub Actions 自动发布 Release 流程

### v1.1.0

- 预览引擎迁移：`flutter_markdown` → `gpt_markdown`
- 新增 LaTeX 数学公式支持
- 新增 Mermaid 图表渲染
- 修复 Android 文件保存、历史重打开等问题

### v1.0.0

- 初始版本：GFM 编辑预览、本地文件管理、历史记录和深色模式

## License

MIT
