# Findings & Decisions

## Requirements
- Fix real bugs in the `md_editor` Flutter markdown editor app

## Research Findings

### Bug Inventory (from code review)

**Bug #1 — Test file is template stub**
- `test/widget_test.dart` contains the default Flutter counter app test (looking for `'0'`, `'1'`, `Icons.add`)
- This has nothing to do with the markdown editor and will fail/be irrelevant
- Needs to be rewritten to test actual editor functionality

**Bug #2 — Syntax highlighter doesn't highlight**
- `markdown_preview.dart` has `_CustomSyntaxHighlighter` extending `SyntaxHighlighter`
- The `format()` method returns the source as plain unhighlighted `TextSpan`
- `flutter_highlighter` is already imported as a dependency but never used for highlighting
- The `github` theme is imported but unused
- Proper fix: Use `Highlight(source: source, language: '', theme: githubTheme)` from flutter_highlighter

**Bug #3 — Code block toolbar insert adds leading newline**
- `editor_toolbar.dart` line 153: `_insertBlock('\n```\ncode block\n```\n')`
- The leading `\n` creates a blank line above the code block, even when cursor is at document start
- Fix: `_insertBlock('```\ncode block\n```\n')`

**Bug #4 — WillPopScope is deprecated**
- `editor_page.dart` line 228: `WillPopScope` is deprecated in Flutter 3.16+
- Should be replaced with `PopScope` with `onPopInvokedWithResult` (or `onPopInvoked`)
- This will produce deprecation warnings and may break in future Flutter versions

**Bug #5 — `_insertAround` uses `textInside` with potential edge cases**
- `editor_toolbar.dart` line 19: `textInside(text)` works for valid selections
- If selection is reversed (base before extent), `textInside` still returns correct content since it uses `start` and `end` normalized
- Actually `textInside` doesn't handle base/extent — it uses `start` and `end`. This should be fine.
- No action needed — not actually a bug

**Bug #6 — `Color.withValues(alpha: ...)` requires recent Flutter**
- `home_page.dart` lines 127, 299, 305 use `withValues(alpha: 0.7)` and `withValues(alpha: 0.5)`
- Also in `markdown_preview.dart` line 68, 78: `withValues(alpha: 0.7)` and `withValues(alpha: 0.3)`
- And in `editor_toolbar.dart` line 204: `withValues(alpha: 0.3)`
- `withValues` was added in Flutter 3.27 / Dart SDK 3.7
- If using older Flutter, this breaks compilation. But if it's already compiling, leave as-is.
- **Decision:** Check Flutter version first; if < 3.27, replace with `withOpacity()`

## Technical Decisions
| Decision | Rationale |
|----------|-----------|
| Fix widget_test.dart first | Dead-simple change, immediately verifiable with `flutter test` |
| Use `Highlight` class from flutter_highlighter | Already in dependencies; just needs proper wiring |
| Use `PopScope` replacement | Follow Flutter deprecation policy |
| Remove leading `\n` from code block insert | Clean UX — no blank line at document start |

## Issues Encountered
| Issue | Resolution |
|-------|------------|
| TBD   |            |

## Resources
- `flutter_highlighter` docs: https://pub.dev/packages/flutter_highlighter
- `PopScope` migration: https://docs.flutter.dev/release/breaking-changes/default-popsystem
- Project root: D:\github\markdown_app
- Source files: lib/main.dart, lib/pages/, lib/widgets/, lib/services/, lib/models/
