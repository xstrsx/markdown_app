import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:md_editor/models/app_settings.dart';
import 'package:md_editor/models/webdav_entry.dart';
import 'package:md_editor/pages/webdav_file_picker_page.dart';
import 'package:md_editor/services/webdav_service.dart';

class PickerFakeGateway implements WebDavGateway {
  final Map<String, List<WebDavEntry>> directories;

  PickerFakeGateway(this.directories);

  @override
  Future<void> ping() async {}

  @override
  Future<List<WebDavEntry>> readDirectory(String path) async =>
      directories[path] ?? [];

  @override
  Future<List<int>> readFile(String path) async => [];

  @override
  Future<void> writeFile(String path, List<int> bytes) async {}

  @override
  Future<void> makeDirectory(String path) async {}
}

WebDavService pickerService() {
  return WebDavService(
    const WebDavConfig(
      enabled: true,
      serverUrl: 'https://dav.example.com',
      username: '',
      rootPath: '/notes',
      password: '',
    ),
    gateway: PickerFakeGateway({
      '/notes': [
        const WebDavEntry(
          name: 'sub',
          path: '/notes/sub',
          type: WebDavEntryType.directory,
        ),
        const WebDavEntry(
          name: 'a.md',
          path: '/notes/a.md',
          type: WebDavEntryType.file,
        ),
        const WebDavEntry(
          name: 'a.txt',
          path: '/notes/a.txt',
          type: WebDavEntryType.file,
        ),
      ],
      '/notes/sub': [],
    }),
  );
}

void main() {
  testWidgets('filters non-Markdown files and enters directories',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: WebDavFilePickerPage(
          service: pickerService(),
          saveMode: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('a.md'), findsOneWidget);
    expect(find.text('a.txt'), findsNothing);

    await tester.tap(find.text('sub'));
    await tester.pumpAndSettle();

    expect(find.text('/notes/sub'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
  });

  testWidgets('save mode rejects path traversal in a filename', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: WebDavFilePickerPage(
          service: pickerService(),
          saveMode: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '../bad.md');
    await tester.tap(find.byType(FilledButton));
    await tester.pump();

    expect(find.text('文件名不能包含路径分隔符或上级目录'), findsOneWidget);
  });

  testWidgets('save mode uses the current file name by default',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: WebDavFilePickerPage(
          service: pickerService(),
          saveMode: true,
          initialFileName: '当前文档.md',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      '当前文档.md',
    );
  });
}
