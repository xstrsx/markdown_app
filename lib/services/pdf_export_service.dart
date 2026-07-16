import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:markdown/markdown.dart' as md;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class PdfExportOptions {
  final PdfPageFormat pageFormat;
  final pw.EdgeInsets pageMargins;
  final String? title;
  final String? author;
  final bool includePageNumbers;

  const PdfExportOptions({
    this.pageFormat = PdfPageFormat.a4,
    this.pageMargins = const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 32),
    this.title,
    this.author,
    this.includePageNumbers = true,
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
  const DefaultPdfImageResolver();

  @override
  Future<Uint8List?> resolve(String source, {String? sourceDirectory}) async {
    final uri = Uri.tryParse(source);
    if (uri != null) {
      if (uri.scheme == 'file') {
        final file = File(uri.toFilePath());
        if (await file.exists()) return await file.readAsBytes();
      } else if (uri.scheme == 'http' || uri.scheme == 'https') {
        final client = HttpClient();
        try {
          final request = await client.getUrl(uri);
          final response = await request.close().timeout(const Duration(seconds: 10));
          if (response.statusCode >= 200 && response.statusCode < 300) {
            final completer = Completer<Uint8List>();
            final builder = BytesBuilder(copy: false);
            response.listen(
              builder.add,
              onDone: () => completer.complete(builder.takeBytes()),
              onError: completer.completeError,
              cancelOnError: true,
            );
            return await completer.future;
          }
        } finally {
          client.close(force: true);
        }
        return null;
      } else if (uri.scheme.isEmpty && sourceDirectory != null) {
        final file = File(_joinPath(sourceDirectory, source));
        if (await file.exists()) return await file.readAsBytes();
      }
    }

    final file = File(source);
    if (await file.exists()) return await file.readAsBytes();
    return null;
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

      final parsed = md.Document(extensionSet: md.ExtensionSet.gitHubWeb)
          .parseLines(const LineSplitter().convert(markdown));
      final warnings = <PdfExportWarning>[];
      final contentWidgets = await _buildWidgets(
        parsed,
        warnings,
        imageResolver,
        sourceDirectory,
      );

      document.addPage(
        pw.MultiPage(
          pageFormat: options.pageFormat,
          margin: options.pageMargins,
          header: options.title == null
              ? null
              : (context) => pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 12),
                    child: pw.Text(
                      options.title!,
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
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

  static Future<List<pw.Widget>> _buildWidgets(
    List<md.Node> nodes,
    List<PdfExportWarning> warnings,
    PdfImageResolver imageResolver,
    String? sourceDirectory,
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
            widgets.add(await _paragraph(node, warnings, imageResolver, sourceDirectory));
            break;
          case 'blockquote':
            widgets.add(_blockquote(node, warnings, imageResolver, sourceDirectory));
            break;
          case 'ul':
          case 'ol':
            widgets.add(_list(node, warnings, imageResolver, sourceDirectory));
            break;
          case 'hr':
            widgets.add(pw.Divider());
            break;
          case 'pre':
            widgets.add(_codeBlock(node));
            break;
          case 'table':
            widgets.add(_table(node));
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
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Text(node.textContent, style: const pw.TextStyle(fontSize: 11, height: 1.5)),
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
      decoration: pw.BoxDecoration(
        color: PdfColors.grey200,
        border: pw.Border(left: pw.BorderSide(color: PdfColors.grey600, width: 3)),
      ),
      child: pw.Text(node.textContent, style: const pw.TextStyle(fontSize: 11, height: 1.5)),
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
                pw.Expanded(child: pw.Text(child.textContent, style: const pw.TextStyle(fontSize: 11, height: 1.4))),
              ],
            ),
          ),
        );
      }
    }
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: items),
    );
  }

  static pw.Widget _codeBlock(md.Element node) {
    final text = node.textContent;
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
        style: pw.TextStyle(fontSize: 9, font: pw.Font.courier()),
      ),
    );
  }

  static pw.Widget _table(md.Element node) {
    final rows = node.children
            ?.whereType<md.Element>()
            .expand((section) => section.children?.whereType<md.Element>() ?? const Iterable<md.Element>.empty())
            .toList() ??
        const <md.Element>[];
    if (rows.isEmpty) return _textBlock(node.textContent);

    final tableRows = <pw.TableRow>[];
    for (final row in rows) {
      final cells = row.children?.whereType<md.Element>().toList() ?? const <md.Element>[];
      tableRows.add(
        pw.TableRow(
          children: [
            for (final cell in cells)
              pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Text(cell.textContent, style: const pw.TextStyle(fontSize: 10)),
              ),
          ],
        ),
      );
    }
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Table(border: pw.TableBorder.all(color: PdfColors.grey400), children: tableRows),
    );
  }

  static pw.Widget _textBlock(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Text(text, style: const pw.TextStyle(fontSize: 11, height: 1.5)),
    );
  }
}
