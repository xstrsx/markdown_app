import 'package:flutter_test/flutter_test.dart';
import 'package:md_editor/export/markdown_ast_parser.dart';

void main() {
  test('parses ordinary blocks into export nodes', () {
    final document = MarkdownAstParser.parse('''# 标题

正文 **粗体** 和 *斜体*

1. 第一项
2. 第二项

```dart
final answer = 42;
```
''');

    expect(document.nodes.map((node) => node.type), [
      MarkdownExportNodeType.heading,
      MarkdownExportNodeType.paragraph,
      MarkdownExportNodeType.orderedList,
      MarkdownExportNodeType.codeBlock,
    ]);
    expect((document.nodes[0] as MarkdownHeadingNode).level, 1);
    expect((document.nodes[2] as MarkdownListNode).items, ['第一项', '第二项']);
    expect((document.nodes[3] as MarkdownCodeBlockNode).language, 'dart');
  });

  test('extracts inline and block LaTeX into the render queue', () {
    final document = MarkdownAstParser.parse(
      r'行内 $x^2$ 公式。' '\n\n' r'$$' '\n' r'\frac{1}{2}' '\n' r'$$',
    );

    expect(document.renderQueue.map((node) => node.renderType), [
      'latex-inline',
      'latex-block',
    ]);
    expect(document.renderQueue[0].content, 'x^2');
    expect(document.renderQueue[1].content, r'\frac{1}{2}');
  });

  test('extracts Mermaid fences while preserving ordinary code fences', () {
    final document = MarkdownAstParser.parse('''```mermaid
graph TD
  A --> B
```

```text
plain code
```
''');

    expect(document.nodes.map((node) => node.type), [
      MarkdownExportNodeType.mermaid,
      MarkdownExportNodeType.codeBlock,
    ]);
    expect((document.nodes[0] as MarkdownMermaidNode).content, contains('A --> B'));
  });
}
