import 'package:flutter_test/flutter_test.dart';
import 'package:md_editor/services/pdf_export_service.dart';

void main() {
  test('returns null instead of throwing for an invalid HTTPS image URL',
      () async {
    const resolver = DefaultPdfImageResolver();

    final result = await resolver.resolve('https://');

    expect(result, isNull);
  });
}
