import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:md_editor/export/export_docx.dart';
import 'package:md_editor/export/headless_webview_render.dart';

class _FakeRenderer implements SvgRenderer {
  final Map<String, String?> results;

  _FakeRenderer(this.results);

  @override
  Future<SvgRenderResult> renderToSvg(String type, String content) async {
    final svg = results[type];
    return svg == null
        ? const SvgRenderResult(
            svg: null,
            failure: SvgRenderFailureKind.renderFailed,
          )
        : SvgRenderResult(svg: svg);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('generates a DOCX ZIP for ordinary Markdown nodes', () async {
    final result = await MarkdownDocxExporter.generate(
      markdown: '# 标题\n\n正文\n\n- 项目\n\n```text\n代码\n```',
    );

    expect(result.bytes.sublist(0, 2), [80, 75]);
    expect(result.warnings, isEmpty);
  });

  test('embeds rendered inline and block SVG formulas', () async {
    final result = await MarkdownDocxExporter.generate(
      markdown: r'行内 $x^2$' '\n\n' r'$$' '\n' r'x^2' '\n' r'$$',
      renderer: _FakeRenderer({
        'latex-inline': '<svg><text>x</text></svg>',
        'latex-block': '<svg><text>block</text></svg>',
      }),
    );

    expect(result.bytes.sublist(0, 2), [80, 75]);
    expect(result.warnings, isEmpty);
  });

  test('falls back without aborting when Mermaid rendering fails', () async {
    final result = await MarkdownDocxExporter.generate(
      markdown: '```mermaid\ngraph TD\n A --> B\n```',
      renderer: _FakeRenderer({}),
    );

    expect(result.bytes.sublist(0, 2), [80, 75]);
    expect(result.warnings.map((warning) => warning.message),
        contains('Mermaid 图表已降级为文本'));
  });

  test('provides a top-level byte export function', () async {
    final bytes = await exportMarkdownToDocx('普通文本');

    expect(bytes, isA<Uint8List>());
    expect(bytes.sublist(0, 2), [80, 75]);
  });
}
