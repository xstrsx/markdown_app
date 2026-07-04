# Markdown Editor

跨平台 Markdown 编辑器，Android & Windows。

> 简洁、流畅的写作体验，所见即所得。

<p align="center">
  <img src="assets/icon/Markdown%20App.png" width="128" alt="icon" />
</p>

## 功能

- **编辑 & 预览** — 桌面端左右分栏，移动端标签页切换
- **GitHub Flavored Markdown** — 表格 / 任务列表 / 表情符号 / 删除线
- **语法高亮** — 代码块自动着色
- **本地文件管理** — 打开 / 编辑 / 保存 / 另存为 Markdown 文件
- **编辑历史** — 最近编辑文件，快速继续工作
- **图片插入** — 从相册选择，实时插入 Markdown 图片语法
- **分享** — 一键分享 Markdown 内容
- **深色模式** — 跟随系统主题自动切换

## 构建

```bash
# Android APK
flutter build apk --release --split-per-abi

# Windows
flutter build windows --release
```

CI 自动构建 → [Actions](https://github.com/xstrsx/markdown_app/actions)

## 技术栈

| 类别 | 选用 |
|------|------|
| 框架 | Flutter 3.44 / Dart 3.12 |
| Markdown 渲染 | flutter_markdown |
| 代码高亮 | highlight + flutter_highlighter (GitHub 主题) |
| 文件操作 | file_picker (桌面) / SAF MethodChannel (Android) |
| 存储权限 | permission_handler (MANAGE_EXTERNAL_STORAGE) |
| 窗口管理 | window_manager |

## Android 权限

应用使用 Android 全文件访问权限以直接读写外部存储中的 Markdown 文件。首次启动需在系统设置中手动开启「允许管理所有文件」开关。

## License

MIT
