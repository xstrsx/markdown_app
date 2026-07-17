# Task Plan: md_editor — 跨平台 Markdown 编辑器

## Goal
维护和增强 Flutter Markdown 编辑器，支持 Android 和 Windows 桌面端，具备完整的文件编辑、保存、历史管理和 CI 自动构建能力。

## Current Phase
维护阶段 — 依赖清理与核心代码审查（2026-07-17）

## Phases

### Phase 1-6: 基础 Bug 修复 (已完成 2026-06-22)
- [x] 重写 widget_test.dart
- [x] 实现语法高亮器
- [x] 修复代码块插入换行问题
- [x] WillPopScope → PopScope 迁移
- [x] flutter_markdown API 兼容性修复
- **Status:** complete

### Phase 7: 软件汉化 (已完成)
- [x] 全部界面文本 → 简体中文
- [x] 测试文件同步更新
- **Status:** complete

### Phase 8: GitHub Actions CI (已完成)
- [x] 创建 build.yml 工作流
- [x] 修复 AGP/Gradle/Kotlin 版本
- [x] 修复 file_picker 依赖升级
- [x] 修复 assets 目录缺失
- [x] 修复 Android 签名配置
- [x] 修复 Windows artifact 路径
- **Status:** complete

### Phase 9: Android 文件操作重写 (已完成)
- [x] 自有 MethodChannel 替换 file_picker (Android)
- [x] ACTION_OPEN_DOCUMENT 添加 WRITE 权限
- [x] saveFileAs 修复空 bytes 写入
- [x] contentUri 追踪和 SAF 写回
- [x] openFileLocation Android 分支
- [x] 显示路径修复（文件名 vs URI）
- [x] 历史记录去重（realPath 解析）
- [x] 退出判断修复（无修改不弹窗）
- [x] MANAGE_EXTERNAL_STORAGE 权限
- [x] 本地内容缓存（持久化，解决重打开空白）
- **Status:** complete

### Phase 10: 第二轮 Bug 修复 (已完成)
- [x] Bug #1: MethodChannel result 重复调用 → else 分支
- [x] Bug #2/#3: 工具栏/图片插入无选区崩溃 → _safePos()
- [x] Bug #4: 路径 lastIndexOf 越界 → sep >= 0 检查
- [x] Bug #5: 窗口大小改变布局不更新 → build 内实时计算
- [x] Bug #6: TextEditingController 泄漏 → dispose()
- [x] Bug #7: 工具栏回调未使用 → 图片/链接按钮调用回调
- [x] Bug #10: 本地图片无法预览 → Image.file + File 检测
- [x] Bug #13: _cachePath 错误值 → file.contentPath
- [x] Bug #14: 缓存同名冲突 → identifier 参数
- **Status:** complete

## Key Questions
1. 下一个任务是什么？（等待用户输入）
2. 是否需要 Google Play 上架？（影响权限策略）
3. 是否需要添加更多功能？（撤销/重做、搜索替换、导出 HTML/PDF）

## Decisions Made
| Decision | Rationale |
|----------|-----------|
| Android 用自有 MethodChannel | file_picker 的 SAF 不返回 WRITE 权限 |
| Android 用 MANAGE_EXTERNAL_STORAGE | 绕过 scoped storage 限制 |
| 持久化内容缓存 | URI 权限过期后仍可重打开历史文件 |
| Windows 保持 file_picker | 桌面端无 SAF 限制，直接文件 I/O 可用 |

## Errors Encountered
| Error | Attempt | Resolution |
|-------|---------|------------|
| file_picker bytes=null 致 saveFileAs 失败 | 1 | 自有 MethodChannel 写入实际内容 |
| resolveRealPath 在 Android 11+ 返回 null | 2 | 本地内容缓存 + contentURI 回退 |
| URI 权限过期致历史重打开空白 | 2 | 持久化 contentPath 缓存 |

### Phase 11: 依赖清理与核心代码审查（已完成）
- [x] 核对直接依赖和源码引用
- [x] 移除无用依赖及废弃 WebView/SVG 渲染资源
- [x] 审查并修复高置信度核心问题
- [x] 运行 `flutter pub get`、`flutter analyze`、`flutter test`
- [x] 提交并推送到 `origin/main`
- **Status:** complete
