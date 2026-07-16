import 'package:flutter_test/flutter_test.dart';
import 'package:md_editor/services/pdf_export_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('reports a warning when Mermaid code is exported', () async {
    final result = await PdfExportService.generate(
      markdown: '```mermaid\ngraph TD\n  A --> B\n```',
    );

    expect(result.bytes.sublist(0, 5), equals([37, 80, 68, 70, 45]));
    expect(
      result.warnings.map((warning) => warning.message),
      contains('Mermaid 图表已降级为源码'),
    );
  });

  test('reports a warning when LaTeX is exported as text', () async {
    final result = await PdfExportService.generate(
      markdown: r'公式：$x^2 + y^2$。',
    );

    expect(
      result.warnings.map((warning) => warning.message),
      contains('LaTeX 公式已降级为文本'),
    );
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
