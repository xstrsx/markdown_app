# DOCX Export Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add offline Markdown-to-DOCX export for Android and Windows, using a headless system WebView only during export for LaTeX and Mermaid SVG rendering.

**Architecture:** Parse Markdown once into an export-specific AST. Pass special nodes through an injected `SvgRenderer`, whose production implementation owns platform WebView lifecycle and whose test implementation is deterministic. Generate DOCX bytes from the AST, preserve feature fallbacks and warnings, then reuse `FileService.saveBytesAs` from the history-page menu.

**Tech Stack:** Flutter/Dart, `markdown`, `docx`, `flutter_inappwebview`, `convert_svg`, Flutter tests, local KaTeX/Mermaid assets.

## Global Constraints

- Android creates `HeadlessInAppWebView` only when DOCX export renders a special node and disposes it immediately afterward.
- Windows checks WebView2 before rendering and displays: `当前Windows缺少WebView2运行时，无法渲染LaTeX公式和Mermaid图表，仅导出普通文本内容`.
- Render assets are local-only under `assets/render_assets`; no CDN, Pandoc, Node.js, or embedded JavaScript strings.
- Existing editor preview and `flutter_math_fork` code remain unchanged.
- DOCX export is available only from the history-page file menu; the editor page gets no new entry.
- Do not run Android or Windows packaging commands; verify with tests and `flutter analyze` only.

### Task 1: Configure DOCX dependencies and define parser contracts

**Files:**
- Modify: `pubspec.yaml`
- Create: `lib/export/markdown_ast_parser.dart`
- Create: `test/markdown_ast_parser_test.dart`

**Interfaces:**
- `MarkdownExportDocument MarkdownAstParser.parse(String markdown)`
- `MarkdownExportNode` subclasses expose `type`, source text where applicable, and child nodes.
- Special nodes expose `renderType` (`latex-inline`, `latex-block`, or `mermaid`) and `content`.

- [ ] Write tests for headings/paragraphs/lists, inline and block formulas, Mermaid fences, and ordinary code fences.
- [ ] Run `flutter test test/markdown_ast_parser_test.dart`; expect failure because parser classes do not exist.
- [ ] Add requested dependency versions: `markdown: ^7.3.1`, `docx: ^0.4.18`, `flutter_inappwebview: ^6.1.0`, `convert_svg: ^0.1.3`.
- [ ] Implement parser with `markdown` AST nodes and explicit special-node extraction without changing preview code.
- [ ] Run the parser test and confirm it passes.

### Task 2: Add offline rendering assets and renderer abstraction

**Files:**
- Create: `assets/render_assets/render.html`
- Create: `assets/render_assets/katex.min.js`
- Create: `assets/render_assets/katex.min.css`
- Create: `assets/render_assets/mermaid.min.js`
- Modify: `pubspec.yaml`
- Create: `lib/export/headless_webview_render.dart`
- Create: `test/headless_webview_render_test.dart`

**Interfaces:**
- `abstract class SvgRenderer { Future<SvgRenderResult> renderToSvg(String type, String content); }`
- `SvgRenderResult` contains nullable SVG, `SvgRenderFailureKind`, and an optional user-facing warning.
- `HeadlessWebViewRenderer({required TargetPlatform platform, ...})` implements `SvgRenderer`.
- `Future<bool> isWebView2Available()` is isolated behind the Windows environment adapter.

- [ ] Add renderer tests using injected bridge/environment doubles for success, JS failure, renderer exception, and Windows WebView2 unavailable cases.
- [ ] Run the renderer test; expect failure because the abstraction does not exist.
- [ ] Add the four offline assets to `flutter.assets`.
- [ ] Implement local resource loading, one WebView instance per export render session, JS bridge callback, exception logging, and guaranteed disposal.
- [ ] Ensure Android does not instantiate the renderer until `renderToSvg` is called.
- [ ] Implement Windows unavailable result with the exact warning text and no SVG attempt.
- [ ] Run renderer tests and confirm they pass.

### Task 3: Implement DOCX generation with injectable rendering

**Files:**
- Create: `lib/export/export_docx.dart`
- Create: `test/docx_export_test.dart`

**Interfaces:**
- `DocxExportResult { Uint8List bytes; List<DocxExportWarning> warnings; }`
- `Future<DocxExportResult> MarkdownDocxExporter.generate({required String markdown, SvgRenderer? renderer, String? title})`
- `Future<Uint8List> exportMarkdownToDocx(String markdown, {SvgRenderer? renderer, String? title})` is the top-level convenience API.

- [ ] Write tests that generate a valid ZIP/DOCX payload with headings, Chinese text, lists, code blocks, tables, and an injected SVG renderer.
- [ ] Write tests that assert inline LaTeX falls back to raw source, block LaTeX is centered when rendered, Mermaid uses bounded image insertion, and failed Mermaid writes `图表渲染失败` plus a warning.
- [ ] Run the DOCX tests; expect failure because exporter APIs do not exist.
- [ ] Implement native Word paragraphs/headings/lists/tables, Noto Sans SC font configuration, code-block monospace styling with gray background, and image insertion through `convert_svg`.
- [ ] Keep the whole export resilient: a node render failure becomes a warning and does not abort document generation.
- [ ] Run DOCX tests and confirm they pass.

### Task 4: Reuse byte-save flow and add history-page DOCX entry

**Files:**
- Modify: `lib/pages/history_page.dart`
- Modify: `lib/services/file_service.dart`
- Modify: `android/app/src/main/kotlin/com/xstrsx/mdeditor/MainActivity.kt` only if the existing generic byte save path cannot preserve DOCX MIME/name.
- Modify: `test/file_service_test.dart` if save metadata needs coverage.
- Create or extend: `test/history_page_test.dart` only if an isolated widget test is needed.

**Interfaces:**
- Existing `FileService.saveBytesAs({required Uint8List bytes, required String defaultName, required String mimeType})` remains the save boundary.
- DOCX uses `application/vnd.openxmlformats-officedocument.wordprocessingml.document` and a `.docx` default name.

- [ ] Add a failing widget/service test for the history menu item and DOCX save metadata.
- [ ] Run the focused test and confirm failure.
- [ ] Add a separate `_isExportingDocx` guard and progress/failure/success messages analogous to PDF, without sharing mutable PDF state.
- [ ] Read the history file content using the current path/content-URI behavior, call the exporter, then save bytes with the DOCX MIME type.
- [ ] Show the exact WebView2 warning when the renderer reports it, while still saving the text-only DOCX.
- [ ] Treat save cancellation as non-error and suppress raw exception details.
- [ ] Run focused tests and confirm they pass.

### Task 5: Full static/test verification

**Files:**
- Modify only files required by failing verification.

- [ ] Run `flutter test test/markdown_ast_parser_test.dart test/headless_webview_render_test.dart test/docx_export_test.dart test/file_service_test.dart test/widget_test.dart`.
- [ ] Run `flutter analyze`.
- [ ] Confirm no `flutter build`, APK/AAB build, Windows build, or packaging command was executed.
- [ ] Inspect `git diff` and `git status --short`; keep unrelated `.claude/` changes untouched.

