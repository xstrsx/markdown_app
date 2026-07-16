import 'dart:convert';

import 'package:docx_creator/docx_creator.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'headless_webview_render.dart';
import 'markdown_ast_parser.dart';

class DocxExportWarning {
  final String message;

  const DocxExportWarning(this.message);
}

class DocxExportResult {
  final Uint8List bytes;
  final List<DocxExportWarning> warnings;

  const DocxExportResult({required this.bytes, this.warnings = const []});
}

class MarkdownDocxExporter {
  const MarkdownDocxExporter._();

  static Future<DocxExportResult> generate({
    required String markdown,
    SvgRenderer? renderer,
    String? title,
  }) async {
    final document = MarkdownAstParser.parse(markdown);
    final warnings = <DocxExportWarning>[];
    final svgRenderer = renderer ??
        HeadlessWebViewRenderer(
          platform: defaultTargetPlatform,
        );
    final builder = docx().section(
      pageSize: DocxPageSize.a4,
      marginTop: 720,
      marginBottom: 720,
      marginLeft: 900,
      marginRight: 900,
    );

    try {
      final fontData = await rootBundle.load('assets/fonts/NotoSansSC-Regular.ttf');
      builder.addFont('Noto Sans SC', fontData.buffer.asUint8List());
    } catch (error) {
      debugPrint('DOCX 中文字体加载失败: $error');
    }

    if (title != null && title.trim().isNotEmpty) {
      builder.heading1(title.trim());
    }

    for (final node in document.nodes) {
      await _appendNode(builder, node, svgRenderer, warnings);
    }

    final bytes = await DocxExporter().exportToBytes(builder.build());
    return DocxExportResult(bytes: bytes, warnings: warnings);
  }

  static Future<void> _appendNode(
    DocxDocumentBuilder builder,
    MarkdownExportNode node,
    SvgRenderer renderer,
    List<DocxExportWarning> warnings,
  ) async {
    switch (node.type) {
      case MarkdownExportNodeType.heading:
        final heading = node as MarkdownHeadingNode;
        builder.heading(_headingLevel(heading.level), heading.text);
        return;
      case MarkdownExportNodeType.paragraph:
        final paragraph = node as MarkdownParagraphNode;
        final children = <DocxInline>[];
        for (final inline in paragraph.inlines) {
          if (inline is MarkdownInlineFormula) {
            final result = await renderer.renderToSvg('latex-inline', inline.text);
            if (result.isSuccess) {
              children.add(DocxInlineImage(
                bytes: Uint8List.fromList(utf8.encode(result.svg!)),
                extension: 'svg',
                width: 48,
                height: 18,
                altText: 'LaTeX formula',
              ));
            } else {
              children.add(DocxText('\$${inline.text}\$'));
              warnings.add(const DocxExportWarning('LaTeX 公式已降级为文本'));
            }
          } else {
            children.add(DocxText(inline.text, fontFamily: 'Noto Sans SC'));
          }
        }
        builder.paragraph(DocxParagraph(
          children: children,
          spacingAfter: 160,
          lineSpacing: 276,
        ));
        return;
      case MarkdownExportNodeType.latexBlock:
        final formula = node as MarkdownRenderNode;
        await _appendRenderedBlock(
          builder,
          formula,
          renderer,
          warnings,
          fallback: '\$\$\n${formula.content}\n\$\$',
          warning: 'LaTeX 公式已降级为文本',
        );
        return;
      case MarkdownExportNodeType.mermaid:
        final mermaid = node as MarkdownMermaidNode;
        await _appendRenderedBlock(
          builder,
          mermaid,
          renderer,
          warnings,
          fallback: '图表渲染失败',
          warning: 'Mermaid 图表已降级为文本',
        );
        return;
      case MarkdownExportNodeType.orderedList:
        builder.numbered((node as MarkdownListNode).items);
        return;
      case MarkdownExportNodeType.unorderedList:
        builder.bullet((node as MarkdownListNode).items);
        return;
      case MarkdownExportNodeType.blockquote:
        builder.quote((node as MarkdownBlockquoteNode).text);
        return;
      case MarkdownExportNodeType.codeBlock:
        builder.code((node as MarkdownCodeBlockNode).content);
        return;
      case MarkdownExportNodeType.table:
        builder.table((node as MarkdownTableNode).rows);
        return;
      case MarkdownExportNodeType.image:
        final image = node as MarkdownImageNode;
        builder.p(image.alt.isEmpty ? '图片无法导出' : image.alt);
        return;
      case MarkdownExportNodeType.horizontalRule:
        builder.hr();
        return;
      case MarkdownExportNodeType.text:
      case MarkdownExportNodeType.latexInline:
        builder.p(node is MarkdownRenderNode ? node.content : '');
        return;
    }
  }

  static Future<void> _appendRenderedBlock(
    DocxDocumentBuilder builder,
    MarkdownRenderNode node,
    SvgRenderer renderer,
    List<DocxExportWarning> warnings, {
    required String fallback,
    required String warning,
  }) async {
    final result = await renderer.renderToSvg(node.renderType, node.content);
    if (result.isSuccess) {
      builder.add(DocxImage(
        bytes: Uint8List.fromList(utf8.encode(result.svg!)),
        extension: 'svg',
        width: node.renderType == 'mermaid' ? 480 : 360,
        height: node.renderType == 'mermaid' ? 260 : 120,
        align: DocxAlign.center,
      ));
      return;
    }
    builder.p(fallback);
    warnings.add(DocxExportWarning(result.warning ?? warning));
  }

  static DocxHeadingLevel _headingLevel(int level) => switch (level) {
        1 => DocxHeadingLevel.h1,
        2 => DocxHeadingLevel.h2,
        3 => DocxHeadingLevel.h3,
        4 => DocxHeadingLevel.h4,
        5 => DocxHeadingLevel.h5,
        _ => DocxHeadingLevel.h6,
      };
}

Future<Uint8List> exportMarkdownToDocx(
  String markdown, {
  SvgRenderer? renderer,
  String? title,
}) async {
  final result = await MarkdownDocxExporter.generate(
    markdown: markdown,
    renderer: renderer,
    title: title,
  );
  return result.bytes;
}
