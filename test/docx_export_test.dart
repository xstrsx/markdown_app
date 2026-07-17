import 'dart:typed_data';

import 'package:docx_creator/docx_creator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:md_editor/export/export_docx.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('generates a DOCX ZIP for ordinary Markdown nodes', () async {
    final result = await MarkdownDocxExporter.generate(
      markdown: '# 标题\n\n正文\n\n- 项目\n\n```text\n代码\n```',
    );

    expect(result.bytes.sublist(0, 2), [80, 75]);
    expect(result.warnings, isEmpty);
  });

  test('uses docx_creator MarkdownParser and preserves inline formatting',
      () async {
    final result = await MarkdownDocxExporter.generate(
      markdown: '''# 标题

正文 **粗体**、*斜体*、~~删除线~~、`代码` 和 [链接](https://example.com)。

- **项目**
''',
    );

    final document = await DocxReader.loadFromBytes(result.bytes);
    final paragraphs = document.elements.whereType<DocxParagraph>().toList();
    final paragraph = paragraphs.firstWhere(
      (item) => item.children.whereType<DocxText>().any(
            (text) => text.content.contains('粗体'),
          ),
    );
    final runs = paragraph.children.whereType<DocxText>().toList();

    expect(runs.any((text) => text.content == '粗体' && text.isBold), isTrue);
    expect(runs.any((text) => text.content == '斜体' && text.isItalic), isTrue);
    expect(
      runs.any((text) => text.content == '删除线' && text.isStrike),
      isTrue,
    );
    expect(
      runs.any(
          (text) => text.content == '代码' && text.fontFamily == 'Courier New'),
      isTrue,
    );
    expect(
      runs.any(
          (text) => text.content == '链接' && text.href == 'https://example.com'),
      isTrue,
    );
    final lists = document.elements.whereType<DocxList>().toList();
    expect(
      lists.any((list) => list.items.any((item) => item.children
          .whereType<DocxText>()
          .any((text) => text.content == '项目' && text.isBold))),
      isTrue,
    );
  });

  test('keeps inline and block LaTeX source editable', () async {
    final result = await MarkdownDocxExporter.generate(
      markdown: r'行内 $x^2$' '\n\n' r'$$' '\n' r'x^2' '\n' r'$$',
    );

    expect(result.bytes.sublist(0, 2), [80, 75]);
    expect(result.warnings, isEmpty);
  });

  test('keeps Mermaid source in a code block', () async {
    final result = await MarkdownDocxExporter.generate(
      markdown: '```mermaid\ngraph TD\n A --> B\n```',
    );

    expect(result.bytes.sublist(0, 2), [80, 75]);
    expect(result.warnings, isEmpty);
  });

  test('provides a top-level byte export function', () async {
    final bytes = await exportMarkdownToDocx('普通文本');

    expect(bytes, isA<Uint8List>());
    expect(bytes.sublist(0, 2), [80, 75]);
  });
}
