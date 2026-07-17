import 'package:flutter_test/flutter_test.dart';
import 'package:md_editor/services/pdf_export_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('keeps Mermaid source without SVG rendering', () async {
    final result = await PdfExportService.generate(
      markdown: '```mermaid\ngraph TD\n  A --> B\n```',
    );

    expect(result.bytes.sublist(0, 5), equals([37, 80, 68, 70, 45]));
    expect(result.warnings, isEmpty);
  });

  test('normalizes inline and block LaTeX to standard delimiters', () async {
    final result = await PdfExportService.generate(
      markdown: r'行内：$x^2$。' '\n\n' r'$$' '\n' r'\frac{1}{2}' '\n' r'$$',
    );

    expect(result.bytes.sublist(0, 5), equals([37, 80, 68, 70, 45]));
    expect(result.warnings, isEmpty);
  });

  test('rejects oversized local image data through the resolver limit',
      () async {
    const resolver = DefaultPdfImageResolver(maxBytes: 4);
    final result = await resolver.resolve(
      'test-image.bin',
      sourceDirectory: 'test',
    );

    expect(result, isNull);
  });

  test('keeps a valid PDF when an image cannot be resolved', () async {
    final result = await PdfExportService.generate(
      markdown: '![missing](missing-image.png)',
    );

    expect(result.bytes, isNotEmpty);
    expect(result.warnings, isNotEmpty);
  });
}
