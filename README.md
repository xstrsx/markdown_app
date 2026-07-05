# Markdown Editor

跨平台 Markdown 编辑器 — Android & Windows。

> 所见即所得 · LaTeX 数学公式 · Mermaid 图表 · GFM 完整支持

<p align="center">
  <img src="assets/icon/Markdown%20App.png" width="128" alt="icon" />
</p>

## 功能

- **编辑 & 预览** — 桌面端左右分栏，移动端标签页切换
- **LaTeX 数学公式** — `$...$` 行内 / `$$...$$` 块级公式，实时渲染
- **Mermaid 图表** — 流程图 / 时序图 / 甘特图 等
- **GFM 完整支持** — 表格 / 任务列表 / 删除线 / 表情符号
- **语法高亮** — 代码块自动着色
- **本地文件** — 打开 / 编辑 / 保存 / 另存为，直接覆盖原文件
- **编辑历史** — 最近文件快速接续，支持持久化缓存
- **图片插入** — 相册选择，本地 & 网络图片混合预览
- **分享** — 一键分享 Markdown 内容
- **深色模式** — 跟随系统主题

## 构建

```bash
# Android APK (按架构分包)
flutter build apk --release --split-per-abi

# Windows 可执行文件
flutter build windows --release
```

CI 自动构建 → [Actions](https://github.com/xstrsx/markdown_app/actions)

## 技术栈

| 类别 | 选用 |
|------|------|
| 框架 | Flutter 3.44 / Dart 3.12 |
| Markdown 渲染 | gpt_markdown |
| LaTeX | flutter_math_fork (通过 gpt_markdown 内置) |
| Mermaid | flutter_mermaid |
| 文件操作 | file_picker (桌面) / SAF MethodChannel (Android) |
| 权限 | permission_handler (MANAGE_EXTERNAL_STORAGE) |
| 窗口 | window_manager |

## Android 权限

首次启动需在系统设置中手动开启「允许管理所有文件」开关，以支持对外部存储中 Markdown 文件的直接读写。

## Changelog

### v1.1.0
- 预览引擎迁移：`flutter_markdown` → `gpt_markdown`
- 新增 LaTeX 数学公式支持
- 新增 Mermaid 图表渲染
- 修复 Android 文件保存、历史重打开等多项 issue

### v1.0.0
- 初始版本：GFM 编辑预览 / 本地文件管理 / 历史记录 / 深色模式

## License

MIT
