import 'package:flutter_test/flutter_test.dart';
import 'package:md_editor/services/pdf_export_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('exports emoji text without throwing', () async {
    final result = await PdfExportService.generate(
      markdown: 'Emoji: 😀 🚀 ❤️ ✅ 🎉',
    );

    expect(result.bytes.sublist(0, 5), equals([37, 80, 68, 70, 45]));
  });

  test('exports emoji in a markdown table without throwing', () async {
    final result = await PdfExportService.generate(
      markdown: '| 状态 | 图标 |\n| --- | --- |\n| 完成 | ✅ 🎉 |',
    );

    expect(result.bytes.sublist(0, 5), equals([37, 80, 68, 70, 45]));
  });
}
