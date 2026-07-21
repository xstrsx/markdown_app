import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:md_editor/models/app_settings.dart';
import 'package:md_editor/models/markdown_file.dart';
import 'package:md_editor/models/webdav_entry.dart';
import 'package:md_editor/pages/editor_page.dart';
import 'package:md_editor/services/history_service.dart';
import 'package:md_editor/services/webdav_service.dart';

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

  test('uses the configured remote sync interval only when active', () {
    expect(
      remoteSyncDuration(
        enabled: true,
        webDavConfigured: true,
        seconds: 30,
      ),
      const Duration(seconds: 30),
    );
    expect(
      remoteSyncDuration(
        enabled: true,
        webDavConfigured: false,
        seconds: 30,
      ),
      isNull,
    );
    expect(
      remoteSyncDuration(
        enabled: false,
        webDavConfigured: true,
        seconds: 30,
      ),
      isNull,
    );
  });

  test('detects remote snapshot changes', () {
    final baseline = DateTime(2026, 7, 21, 10, 30);

    expect(
      remoteSnapshotChanged(
        baselineModified: baseline,
        baselineSize: 12,
        remoteModified: baseline,
        remoteSize: 12,
      ),
      isFalse,
    );
    expect(
      remoteSnapshotChanged(
        baselineModified: baseline,
        baselineSize: 12,
        remoteModified: baseline.add(const Duration(seconds: 1)),
        remoteSize: 12,
      ),
      isTrue,
    );
  });

  test('detects local edits made during a remote reload', () {
    expect(
      remoteReloadConflict(
        localModified: false,
        expectedContent: '# old',
        currentContent: '# old',
      ),
      isFalse,
    );
    expect(
      remoteReloadConflict(
        localModified: true,
        expectedContent: '# old',
        currentContent: '# local',
      ),
      isTrue,
    );
    expect(
      remoteReloadConflict(
        localModified: false,
        expectedContent: '# old',
        currentContent: '# local',
      ),
      isTrue,
    );
  });

  testWidgets('reloads a clean cloud document after a remote update',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final baseline = DateTime(2026, 7, 21, 10, 30);
    final gateway = _EditorFakeGateway(
      content: '# old',
      modified: baseline,
    );
    final settings = ValueNotifier(_cloudSettings());
    addTearDown(settings.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: EditorPage(
          file: _cloudFile(baseline, '# old'),
          settingsListenable: settings,
          webDavServiceFactory: (config) =>
              WebDavService(config, gateway: gateway),
          cacheContent: (content, name, identifier) async => 'memory/$name',
        ),
      ),
    );
    await tester.pumpAndSettle();

    gateway.setRemoteContent('# new', baseline.add(const Duration(seconds: 1)));
    await tester.pump(const Duration(seconds: 6));
    await tester.pump();

    expect(gateway.directoryReads, greaterThan(0));
    expect(find.text('检测到云端文件已更新'), findsNothing);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 2)),
    );
    await tester.pump();
    final editor = tester.widget<TextField>(find.byType(TextField).first);
    expect(editor.controller?.text, '# new');
  });

  testWidgets(
      'shows a conflict and does not auto-overwrite dirty cloud content',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final baseline = DateTime(2026, 7, 21, 10, 30);
    final gateway = _EditorFakeGateway(
      content: '# old',
      modified: baseline,
    );
    final settings = ValueNotifier(_cloudSettings());
    addTearDown(settings.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: EditorPage(
          file: _cloudFile(baseline, '# old'),
          settingsListenable: settings,
          webDavServiceFactory: (config) =>
              WebDavService(config, gateway: gateway),
          cacheContent: (content, name, identifier) async => 'memory/$name',
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField).first, '# local');
    await tester.pump();
    gateway.setRemoteContent(
      '# remote',
      baseline.add(const Duration(seconds: 1)),
    );
    await tester.pump(const Duration(seconds: 6));
    await tester.pump();

    expect(find.text('检测到云端文件已更新'), findsOneWidget);
    expect(utf8.decode(gateway.files['/notes/current.md']!), '# remote');
  });

  testWidgets('checks the remote snapshot again before manual cloud save',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final baseline = DateTime(2026, 7, 21, 10, 30);
    final gateway = _EditorFakeGateway(
      content: '# old',
      modified: baseline,
    );
    final settings = ValueNotifier(_cloudSettings());
    addTearDown(settings.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: EditorPage(
          file: _cloudFile(baseline, '# old'),
          settingsListenable: settings,
          webDavServiceFactory: (config) =>
              WebDavService(config, gateway: gateway),
          cacheContent: (content, name, identifier) async => 'memory/$name',
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField).first, '# local');
    await tester.pump();
    gateway.setRemoteContent(
      '# remote',
      baseline.add(const Duration(seconds: 1)),
    );
    await tester.tap(find.byTooltip('保存'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('检测到云端文件已更新'), findsOneWidget);
    expect(utf8.decode(gateway.files['/notes/current.md']!), '# remote');
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

AppSettings _cloudSettings() {
  return const AppSettings(
    themeMode: ThemeMode.system,
    autoSaveEnabled: true,
    autoSaveMinutes: 60,
    remoteSyncEnabled: true,
    remoteSyncSeconds: 5,
    webDav: WebDavConfig(
      enabled: true,
      serverUrl: 'https://dav.example.com',
      username: '',
      rootPath: '/notes',
      password: '',
    ),
  );
}

MarkdownFile _cloudFile(DateTime modified, String content) {
  return MarkdownFile(
    path: '/notes/current.md',
    remotePath: '/notes/current.md',
    storageType: MarkdownStorageType.webDav,
    name: 'current.md',
    content: content,
    lastModified: DateTime(2026, 7, 21),
    size: content.length,
    remoteModified: modified,
    remoteSize: content.length,
  );
}

class _EditorFakeGateway implements WebDavGateway {
  String content;
  DateTime modified;
  final Map<String, List<int>> files = {};
  int directoryReads = 0;

  _EditorFakeGateway({required this.content, required this.modified}) {
    files['/notes/current.md'] = utf8.encode(content);
  }

  void setRemoteContent(String value, DateTime valueModified) {
    content = value;
    modified = valueModified;
    files['/notes/current.md'] = utf8.encode(value);
  }

  @override
  Future<void> ping() async {}

  @override
  Future<List<WebDavEntry>> readDirectory(String path) async {
    directoryReads++;
    if (path != '/notes') return [];
    return [
      WebDavEntry(
        name: 'current.md',
        path: '/notes/current.md',
        type: WebDavEntryType.file,
        size: files['/notes/current.md']?.length,
        modified: modified,
      ),
    ];
  }

  @override
  Future<List<int>> readFile(String path) async => [...files[path]!];

  @override
  Future<void> writeFile(String path, List<int> bytes) async {
    files[path] = [...bytes];
    content = utf8.decode(bytes);
    modified = DateTime.now();
  }

  @override
  Future<void> makeDirectory(String path) async {}
}
