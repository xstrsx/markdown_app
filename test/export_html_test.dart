import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:md_editor/export/export_html.dart';

void main() {
  test('converts Markdown formatting and special source to HTML', () {
    final html = markdownToHtml(r'''# 标题

正文 **粗体**、*斜体*、~~删除~~、[链接](https://example.com) 和 $x^2$。

$$
E=mc^2
$$

```mermaid
graph TD
  A --> B
```
''', title: '测试文档');

    expect(html, contains('<h1>标题</h1>'));
    expect(html, contains('<strong>粗体</strong>'));
    expect(html, contains('<em>斜体</em>'));
    expect(html, contains('<del>删除</del>'));
    expect(html, contains('<a href="https://example.com">链接</a>'));
    expect(html, contains(r'$$' '\nE=mc^2\n' r'$$'));
    expect(html, contains(r'E=mc^2'));
    expect(html, contains('<div class="mermaid">'));
    expect(html, contains('A --&gt; B'));
    expect(html, contains('https://s4.zstatic.net/ajax/libs/KaTeX/'));
    expect(html, contains('https://s4.zstatic.net/ajax/libs/mermaid/'));
    expect(html, contains('const inlineFormula ='));
  });

  test('escapes HTML content before writing it to the page', () {
    final html = markdownToHtml('<script>alert("x")</script>');

    expect(html, contains('&lt;script&gt;alert("x")&lt;/script&gt;'));
    expect(html, isNot(contains('<script>alert("x")</script>')));
  });

  test('writes an HTML file through the top-level export function', () async {
    final directory = await Directory.systemTemp.createTemp('md_html_');
    addTearDown(() => directory.delete(recursive: true));
    final output = '${directory.path}${Platform.pathSeparator}export.html';

    final result = await exportMarkdownToHtml('# 标题', output);

    expect(result.isSuccess, isTrue);
    expect(await File(output).readAsString(), contains('<h1>标题</h1>'));
  });
}
