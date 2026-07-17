import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:md_editor/services/history_service.dart';

void main() {
  test('skips malformed history records instead of throwing', () async {
    SharedPreferences.setMockInitialValues({
      'markdown_history': [
        '{"path":"notes.md","contentUri":"","contentPath":"","name":"notes.md","lastModified":0,"size":0}',
        '{not valid json}',
      ],
    });

    final history = await HistoryService.getHistory();

    expect(history, hasLength(1));
    expect(history.single.name, 'notes.md');
  });
}
