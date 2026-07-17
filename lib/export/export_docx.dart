import 'package:docx_creator/docx_creator.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

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
    String? title,
  }) async {
    // Ordinary Markdown uses docx_creator's native parser and preserves Word
    // run formatting. Special syntax remains editable source text.
    final warnings = <DocxExportWarning>[];
    final builder = docx().section(
      pageSize: DocxPageSize.a4,
      marginTop: 720,
      marginBottom: 720,
      marginLeft: 900,
      marginRight: 900,
    );

    try {
      final fontData =
          await rootBundle.load('assets/fonts/NotoSansSC-Regular.ttf');
      builder.addFont('Noto Sans SC', fontData.buffer.asUint8List());
    } catch (error) {
      debugPrint('DOCX 中文字体加载失败: $error');
    }

    if (title != null && title.trim().isNotEmpty) {
      builder.heading1(title.trim());
    }

    final nodes = await MarkdownParser.parse(markdown);
    for (final node in nodes) {
      builder.add(node);
    }

    final bytes = await DocxExporter().exportToBytes(builder.build());
    return DocxExportResult(bytes: bytes, warnings: warnings);
  }
}

Future<Uint8List> exportMarkdownToDocx(
  String markdown, {
  String? title,
}) async {
  final result = await MarkdownDocxExporter.generate(
    markdown: markdown,
    title: title,
  );
  return result.bytes;
}
