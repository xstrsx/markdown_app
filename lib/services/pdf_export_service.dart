import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:markdown/markdown.dart' as md;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class PdfExportOptions {
  final PdfPageFormat pageFormat;
  final pw.EdgeInsets pageMargins;
  final String? title;
  final String? author;
  final bool includePageNumbers;
  final double maxImageWidth;
  final double maxImageHeight;
  final int maxRemoteImageBytes;

  const PdfExportOptions({
    this.pageFormat = PdfPageFormat.a4,
    this.pageMargins =
        const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 32),
    this.title,
    this.author,
    this.includePageNumbers = true,
    this.maxImageWidth = 520,
    this.maxImageHeight = 680,
    this.maxRemoteImageBytes = 8 * 1024 * 1024,
  });
}

class PdfExportWarning {
  final String message;

  const PdfExportWarning(this.message);
}

class PdfExportResult {
  final Uint8List bytes;
  final List<PdfExportWarning> warnings;

  const PdfExportResult({required this.bytes, this.warnings = const []});
}

class PdfExportFailure implements Exception {
  final String message;

  const PdfExportFailure(this.message);

  @override
  String toString() => message;
}

abstract class PdfImageResolver {
  Future<Uint8List?> resolve(String source, {String? sourceDirectory});
}

class DefaultPdfImageResolver implements PdfImageResolver {
  final int maxBytes;

  const DefaultPdfImageResolver({this.maxBytes = 8 * 1024 * 1024});

  @override
  Future<Uint8List?> resolve(String source, {String? sourceDirectory}) async {
    final uri = Uri.tryParse(source);
    if (uri != null) {
      if (uri.scheme == 'file') {
        final file = File(uri.toFilePath());
        if (await file.exists()) return _readLocalFile(file);
      } else if ((uri.scheme == 'http' || uri.scheme == 'https') &&
          uri.host.isNotEmpty) {
        final client = HttpClient();
        try {
          final request = await client.getUrl(uri);
          final response =
              await request.close().timeout(const Duration(seconds: 10));
          if (response.statusCode >= 200 && response.statusCode < 300) {
            final bytes = await response.fold<List<int>>(<int>[], (a, b) {
              if (a.length + b.length <= maxBytes) a.addAll(b);
              return a;
            });
            if (bytes.length > maxBytes) return null;
            return Uint8List.fromList(bytes);
          }
        } on SocketException {
          return null;
        } on HandshakeException {
          return null;
        } on TlsException {
          return null;
        } on FormatException {
          return null;
        } finally {
          client.close(force: true);
        }
        return null;
      } else if (uri.scheme.isEmpty && sourceDirectory != null) {
        final file = File(_joinPath(sourceDirectory, source));
        if (await file.exists()) return _readLocalFile(file);
      }
    }

    final file = File(source);
    if (await file.exists()) return _readLocalFile(file);
    return null;
  }

  Future<Uint8List?> _readLocalFile(File file) async {
    if (await file.length() > maxBytes) return null;
    return await file.readAsBytes();
  }

  String _joinPath(String dir, String path) {
    final separator = Platform.pathSeparator;
    if (dir.endsWith(separator)) return '$dir$path';
    return '$dir$separator$path';
  }
}

class PdfExportService {
  const PdfExportService._();

  static Future<PdfExportResult> generate({
    required String markdown,
    PdfExportOptions options = const PdfExportOptions(),
    PdfImageResolver imageResolver = const DefaultPdfImageResolver(),
    String? sourceDirectory,
  }) async {
    try {
      final document = pw.Document(
        version: PdfVersion.pdf_1_5,
        compress: true,
        title: options.title,
        author: options.author,
      );

      final fontData =
          await rootBundle.load('assets/fonts/NotoSansSC-Regular.ttf');
      final emojiFontData = await rootBundle
          .load('assets/fonts/NotoColorEmoji_WindowsCompatible.ttf');
      final regularFont = pw.Font.ttf(fontData);
      final emojiFont = pw.Font.ttf(emojiFontData);
      final boldFont = regularFont;

      final parsed =
          md.Document(extensionSet: md.ExtensionSet.gitHubWeb).parse(markdown);
      final warnings = <PdfExportWarning>[];
      await _collectFeatureWarnings(
        markdown,
        warnings,
        imageResolver,
        sourceDirectory,
      );
      final contentWidgets = await _buildWidgets(
        parsed,
        warnings,
        imageResolver,
        sourceDirectory,
        regularFont,
        emojiFont,
      );

      document.addPage(
        pw.MultiPage(
          pageFormat: options.pageFormat,
          margin: options.pageMargins,
          theme: pw.ThemeData.withFont(
            base: regularFont,
            bold: boldFont,
            italic: regularFont,
            boldItalic: boldFont,
            fontFallback: [emojiFont],
          ),
          header: null,
          footer: options.includePageNumbers
              ? (context) => pw.Align(
                    alignment: pw.Alignment.centerRight,
                    child: pw.Text(
                      '${context.pageNumber} / ${context.pagesCount}',
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  )
              : null,
          build: (context) => contentWidgets,
        ),
      );

      return PdfExportResult(bytes: await document.save(), warnings: warnings);
    } catch (error) {
      throw PdfExportFailure(error.toString());
    }
  }

  static Future<void> _collectFeatureWarnings(
    String markdown,
    List<PdfExportWarning> warnings,
    PdfImageResolver imageResolver,
    String? sourceDirectory,
  ) async {
    if (RegExp(r'(^|\n)```\s*mermaid\b', caseSensitive: false)
        .hasMatch(markdown)) {
      warnings.add(const PdfExportWarning('Mermaid 图表已降级为源码'));
    }
    if (markdown.contains(r'$$') ||
        RegExp(r'\$[^\n$]+\$').hasMatch(markdown) ||
        markdown.contains(r'\\(') ||
        markdown.contains(r'\\[')) {
      warnings.add(const PdfExportWarning('LaTeX 公式已降级为文本'));
    }
    if (RegExp(r'!\[[^\]]*\]\([^)]*\)').hasMatch(markdown)) {
      warnings.add(const PdfExportWarning('图片将尝试嵌入 PDF'));
    }
  }

  static Future<List<pw.Widget>> _buildWidgets(
    List<md.Node> nodes,
    List<PdfExportWarning> warnings,
    PdfImageResolver imageResolver,
    String? sourceDirectory,
    pw.Font regularFont,
    pw.Font emojiFont,
  ) async {
    final widgets = <pw.Widget>[];
    for (final node in nodes) {
      if (node is md.Element) {
        switch (node.tag) {
          case 'h1':
          case 'h2':
          case 'h3':
          case 'h4':
          case 'h5':
          case 'h6':
            widgets.add(_heading(node));
            break;
          case 'p':
            widgets.add(await _paragraph(
              node,
              warnings,
              imageResolver,
              sourceDirectory,
            ));
            break;
          case 'blockquote':
            widgets.add(
                _blockquote(node, warnings, imageResolver, sourceDirectory));
            break;
          case 'ul':
          case 'ol':
            widgets.add(_list(node, warnings, imageResolver, sourceDirectory));
            break;
          case 'hr':
            widgets.add(pw.Divider());
            break;
          case 'pre':
            widgets.add(_codeBlock(node, warnings, regularFont, emojiFont));
            break;
          case 'table':
            widgets.add(_table(node));
            break;
          case 'img':
            widgets.add(await _image(
              node.attributes['src'] ?? '',
              node.attributes['alt'],
              warnings,
              imageResolver,
              sourceDirectory,
            ));
            break;
          default:
            widgets.add(_textBlock(node.textContent));
            break;
        }
      } else if (node.textContent.trim().isNotEmpty) {
        widgets.add(_textBlock(node.textContent));
      }
    }
    return widgets;
  }

  static pw.Widget _heading(md.Element node) {
    final level = int.tryParse(node.tag.substring(1)) ?? 1;
    final size = switch (level) {
      1 => 20.0,
      2 => 18.0,
      3 => 16.0,
      4 => 14.0,
      5 => 12.0,
      _ => 11.0,
    };
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8, top: 12),
      child: pw.Text(
        node.textContent,
        style: pw.TextStyle(fontSize: size, fontWeight: pw.FontWeight.bold),
      ),
    );
  }

  static Future<pw.Widget> _paragraph(
    md.Element node,
    List<PdfExportWarning> warnings,
    PdfImageResolver imageResolver,
    String? sourceDirectory,
  ) async {
    final image = node.children
        ?.whereType<md.Element>()
        .where((child) => child.tag == 'img')
        .firstOrNull;
    if (image != null) {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          await _image(
            image.attributes['src'] ?? '',
            image.attributes['alt'],
            warnings,
            imageResolver,
            sourceDirectory,
          ),
          if (node.textContent.trim().isNotEmpty &&
              node.textContent.trim() != image.textContent.trim())
            _textBlock(node.textContent),
        ],
      );
    }
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Text(node.textContent,
          style: const pw.TextStyle(fontSize: 11, height: 1.5)),
    );
  }

  static pw.Widget _blockquote(
    md.Element node,
    List<PdfExportWarning> warnings,
    PdfImageResolver imageResolver,
    String? sourceDirectory,
  ) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 8),
      padding: const pw.EdgeInsets.all(10),
      decoration: const pw.BoxDecoration(
        color: PdfColors.grey200,
        border: pw.Border(
          left: pw.BorderSide(color: PdfColors.grey600, width: 3),
        ),
      ),
      child: pw.Text(node.textContent,
          style: const pw.TextStyle(fontSize: 11, height: 1.5)),
    );
  }

  static pw.Widget _list(
    md.Element node,
    List<PdfExportWarning> warnings,
    PdfImageResolver imageResolver,
    String? sourceDirectory,
  ) {
    final ordered = node.tag == 'ol';
    final items = <pw.Widget>[];
    var index = 1;
    for (final child in node.children ?? const <md.Node>[]) {
      if (child is md.Element && child.tag == 'li') {
        items.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 4),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.SizedBox(
                  width: 18,
                  child: pw.Text(ordered ? '${index++}.' : '•'),
                ),
                pw.Expanded(
                  child: pw.Text(
                    child.textContent,
                    style: const pw.TextStyle(fontSize: 11, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start, children: items),
    );
  }

  static pw.Widget _codeBlock(
    md.Element node,
    List<PdfExportWarning> warnings,
    pw.Font regularFont,
    pw.Font emojiFont,
  ) {
    final text = node.textContent;
    final language = node.attributes['class']?.replaceFirst('language-', '');
    if (language == 'mermaid') {
      warnings.add(const PdfExportWarning('Mermaid 图表已降级为源码'));
      return _warningBlock('Mermaid 图表（源码）\n$text');
    }
    if (text.contains(r'\\(') ||
        text.contains(r'\\[') ||
        text.contains(r'$$')) {
      warnings.add(const PdfExportWarning('LaTeX 公式已降级为文本'));
    }
    return pw.Container(
      width: double.infinity,
      margin: const pw.EdgeInsets.only(bottom: 8),
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(4),
        border: pw.Border.all(color: PdfColors.grey400),
      ),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 9,
          font: regularFont,
          fontFallback: [emojiFont],
        ),
      ),
    );
  }

  static Future<pw.Widget> _image(
    String source,
    String? alt,
    List<PdfExportWarning> warnings,
    PdfImageResolver imageResolver,
    String? sourceDirectory,
  ) async {
    if (source.isEmpty) {
      warnings.add(const PdfExportWarning('图片地址为空'));
      return _warningBlock(alt ?? '图片无法导出');
    }
    final bytes = await imageResolver.resolve(
      source,
      sourceDirectory: sourceDirectory,
    );
    if (bytes == null) {
      warnings.add(PdfExportWarning('图片无法导出: $source'));
      return _warningBlock(alt ?? '图片无法导出');
    }
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Image(
        pw.MemoryImage(bytes),
        fit: pw.BoxFit.contain,
        width: 520,
        height: 680,
      ),
    );
  }

  static pw.Widget _warningBlock(String text) {
    return pw.Container(
      width: double.infinity,
      margin: const pw.EdgeInsets.only(bottom: 8),
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: PdfColors.amber50,
        border: pw.Border.all(color: PdfColors.amber200),
      ),
      child: pw.Text(text, style: const pw.TextStyle(fontSize: 10)),
    );
  }

  static pw.Widget _table(md.Element node) {
    final rows = node.children
            ?.whereType<md.Element>()
            .expand((section) =>
                section.children?.whereType<md.Element>() ??
                const Iterable<md.Element>.empty())
            .toList() ??
        const <md.Element>[];
    if (rows.isEmpty) return _textBlock(node.textContent);

    final tableRows = <pw.TableRow>[];
    for (final row in rows) {
      final cells = row.children?.whereType<md.Element>().toList() ??
          const <md.Element>[];
      tableRows.add(
        pw.TableRow(
          children: [
            for (final cell in cells)
              pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Text(cell.textContent,
                    style: const pw.TextStyle(fontSize: 10)),
              ),
          ],
        ),
      );
    }
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey400),
          children: tableRows),
    );
  }

  static pw.Widget _textBlock(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child:
          pw.Text(text, style: const pw.TextStyle(fontSize: 11, height: 1.5)),
    );
  }
}
