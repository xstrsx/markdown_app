import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:md_editor/models/app_settings.dart';
import 'package:md_editor/models/markdown_file.dart';
import 'package:md_editor/pages/editor_page.dart';
import 'package:md_editor/services/history_service.dart';

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

  testWidgets('records an opened cloud file even when it is not edited',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final settings = ValueNotifier(
      const AppSettings(
        themeMode: ThemeMode.system,
        autoSaveEnabled: true,
        autoSaveMinutes: 1,
        webDav: WebDavConfig(
          enabled: true,
          serverUrl: 'https://dav.example.com',
          username: '',
          rootPath: '/notes',
          password: '',
        ),
      ),
    );
    addTearDown(settings.dispose);

    final file = MarkdownFile(
      path: '/notes/current.md',
      remotePath: '/notes/current.md',
      storageType: MarkdownStorageType.webDav,
      name: 'current.md',
      content: '# Current',
      lastModified: DateTime(2026, 7, 21),
      size: 9,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: EditorPage(
          file: file,
          settingsListenable: settings,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final history = await HistoryService.getHistory();
    expect(history, hasLength(1));
    expect(history.single.remotePath, '/notes/current.md');
  });
}
