import 'package:flutter_test/flutter_test.dart';
import 'package:md_editor/pages/editor_page.dart';

void main() {
  test('detects edits made after the save snapshot was taken', () {
    expect(contentChangedSinceSave('before', 'before'), isFalse);
    expect(contentChangedSinceSave('before', 'after'), isTrue);
  });

  test('uses the configured auto-save interval', () {
    expect(
      autoSaveDuration(enabled: true, minutes: 1),
      const Duration(minutes: 1),
    );
    expect(autoSaveDuration(enabled: false, minutes: 10), isNull);
    expect(
      autoSaveDuration(enabled: true, minutes: 99),
      const Duration(minutes: 60),
    );
  });
}
