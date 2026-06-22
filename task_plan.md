# Task Plan: Fix Bugs in Flutter Markdown Editor

## Goal
Identify and fix all bugs in the `md_editor` Flutter project — including the broken test file, non-functional syntax highlighter, and other code defects.

## Current Phase
Complete

## Phases

### Phase 1: Bug Discovery & Analysis
- [x] Read all source files (lib/, test/)
- [x] Identify and categorize bugs
- [x] Document findings in findings.md
- **Status:** complete

### Phase 2: Fix Bug #1 — Broken widget test
- [x] Read existing test file
- [x] Rewrite widget_test.dart (no longer default Flutter counter template)
- [x] Verify test passes with `flutter test`
- **Status:** complete

### Phase 3: Fix Bug #2 — Syntax highlighter is a no-op stub
- [x] Fixed `_CustomSyntaxHighlighter.format()` to use `highlight.parse()` with github theme
- [x] Tests pass
- **Status:** complete

### Phase 4: Fix Bug #3 — Code block toolbar insert adds leading newline
- [x] Fixed `_insertBlock('\n```\n...')` — removed leading newline
- **Status:** complete

### Phase 5: Fix Bug #4 — Deprecated WillPopScope
- [x] Replaced `WillPopScope` with `PopScope` using `canPop` + `onPopInvokedWithResult`
- **Status:** complete

### Phase 6: Final Verification
- [x] Run `flutter test` — all tests pass
- [x] Run `flutter analyze` — no errors
- **Status:** complete

## Key Questions
1. Which Flutter/Dart SDK version is installed? (Answered: Flutter 3.44.1 / Dart 3.12.1)
2. Should we add more tests beyond fixing the existing one? (Covered basics)

## Decisions Made
| Decision | Rationale |
|----------|-----------|
| Fix highlighter with `highlight.parse()` from highlighter package | Already imported as dependency, just not wired up |
| Replace WillPopScope with PopScope | WillPopScope is deprecated; PopScope is the modern replacement |
| Use `highlight.parse()` without language detection | `flutter_markdown`'s `syntaxHighlighter` only receives source, not language hint |

## Errors Encountered
| Error | Attempt | Resolution |
|-------|---------|------------|
| tableCellsVerticalAlignment not found in flutter_markdown 0.6.23 | 1 | Removed param (no longer in API) |
| horizontalRule not found in flutter_markdown 0.6.23 | 1 | Replaced with horizontalRuleDecoration |

## Notes
- Update phase status as you progress: pending → in_progress → complete
- Re-read this plan before major decisions
- Log ALL errors
