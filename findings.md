# Findings & Decisions

## 2026-07-17 依赖与核心审查

- `pubspec.yaml` 中 `cupertino_icons`、`flutter_markdown`、`flutter_highlighter`、`highlighter`、`http`、`image_picker` 没有 `lib/` 或 `test/` 的直接引用。
- `flutter_math_fork` 没有直接引用，由 `gpt_markdown` 传递使用，移除 direct dependency 后仍会保留在依赖树中。
- `flutter_inappwebview` 仅被 `lib/export/headless_webview_render.dart` 及其测试使用；该路径已经不符合当前“PDF/DOCX 不渲染 SVG、HTML 使用 CDN”的导出约束，可整体删除。
- `assets/render_assets/` 仅被旧 WebView 渲染器和契约测试使用，可随旧路径删除，避免继续打包 KaTeX/Mermaid 本地资源。
- README 技术栈表已移除 `image_picker`；版本记录中的 `flutter_markdown` 迁移文字是历史说明，不代表当前依赖。
- Flutter widget 测试绑定会拦截 `HttpClient` 网络请求并返回 400，无法用本地 HTTP 服务验证远程图片分块读取；该边界改为代码审查后修复，保留可稳定运行的本地大小限制测试。
- 原生打包未能在本机执行：`flutter doctor -v` 显示没有 Android SDK，也没有 Visual Studio Desktop C++ 工具链；`flutter build apk --debug` 和 `flutter build windows --debug` 均在编译前退出。

### 已完成修复

- 移除 6 个无用 direct dependencies，`flutter_math_fork` 和 `http` 保留为现有库的传递依赖。
- 删除旧 InAppWebView SVG 渲染器、测试、本地 KaTeX/Mermaid 资源及自动生成的插件注册项。
- 历史记录逐条容错并记录错误；首页、历史页、编辑器初始化增加异步生命周期保护。
- Android SAF 写回检查真实结果，桌面 Markdown 另存为显式写入并校验文件长度，分享失败不再形成未处理异步异常。
- PDF 远程图片超限返回失败而不是截断数据，且图片尺寸选项现在真正生效；通用 PDF 文本和图片警告使用中文字体回退。

## 项目概况

| 项目 | 值 |
|------|-----|
| 名称 | md_editor |
| 框架 | Flutter 3.44.1 / Dart 3.12.1 |
| 平台 | Android + Windows (desktop) |
| 包名 | com.xstrsx.mdeditor |
| CI | GitHub Actions (build.yml) |

## 架构概述

```
lib/
├── main.dart              # 入口 + 导航（NavigationRail / BottomBar）
├── models/
│   └── markdown_file.dart  # 数据模型（路径、URI、缓存、JSON序列化）
├── pages/
│   ├── home_page.dart      # 首页：新建/打开/最近文件
│   ├── editor_page.dart    # 编辑器：编辑/预览/保存/另存/分享
│   └── history_page.dart   # 历史：列表/详情/删除/打开位置
├── services/
│   ├── file_service.dart   # 文件操作（Android用MethodChannel/桌面用file_picker）
│   └── history_service.dart # 历史持久化（SharedPreferences）
└── widgets/
    ├── editor_toolbar.dart  # 工具栏（标题/格式/列表/代码/表格）
    └── markdown_preview.dart # Markdown渲染（语法高亮/图片/样式）
```

## Android 文件操作机制

### 为什么不用 file_picker？

`file_picker` 的 Android 实现有三大缺陷：
1. `ACTION_OPEN_DOCUMENT` 不带 `FLAG_GRANT_WRITE_URI_PERMISSION`，无法写回原文件
2. `saveFile()` 将 null bytes 写入 OutputStream，创建空文件
3. 总是缓存文件到 app 私有目录，返回缓存路径

### 当前方案

```
picking  → MainActivity.pickFile → ACTION_OPEN_DOCUMENT + WRITE flag
                                    → ContentResolver.takePersistableUriPermission()
                                    → 缓存到 cacheDir → 返回 path+uri+realPath

saving   → file_service.saveFile → writeToUri (SAF OutputStream)
or         file_service.getSavePath → saveFileAs (ACTION_CREATE_DOCUMENT + 内容写入)

caching  → file_service.cacheContent → documentsDir/cache/{name}_{hash}.md
                                     → contentPath 存入 MarkdownFile
                                     → 历史重打开时从缓存加载（URI权限过期后仍可用）
```

## 已知限制

1. **历史文件重打开**：URI 权限在 app 重启后失效，依赖 contentPath 缓存
2. **同名文件缓存**：使用 name + identifier hash 区分，但 identifier 变更会产生新缓存
3. **Android 11+ 路径解析**：`_data` 列可能返回 null，displayPath 仅显示文件名
4. **大文件性能**：`MarkdownFile.fromFile` 同步读取，超大文件可能卡顿

## Resources
- file_picker 8.3.7 源码: `C:/Users/atlas/AppData/Local/Pub/Cache/hosted/pub.dev/file_picker-8.3.7/`
- flutter_markdown 0.6.23 源码: `C:/Users/atlas/AppData/Local/Pub/Cache/hosted/pub.dev/flutter_markdown-0.6.23/`
