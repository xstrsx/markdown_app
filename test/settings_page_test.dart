import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:md_editor/models/app_settings.dart';
import 'package:md_editor/models/webdav_entry.dart';
import 'package:md_editor/pages/settings_page.dart';
import 'package:md_editor/services/webdav_service.dart';

void main() {
  testWidgets('renders theme and auto-save controls', (tester) async {
    final settings = ValueNotifier(const AppSettings.defaults());
    addTearDown(settings.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: SettingsPage(
          settingsListenable: settings,
          onChanged: (value) => settings.value = value,
        ),
      ),
    );

    expect(find.text('浅色模式'), findsOneWidget);
    expect(find.text('深色模式'), findsOneWidget);
    expect(find.text('跟随系统'), findsOneWidget);
    expect(find.text('自动保存'), findsOneWidget);
    expect(find.text('保存间隔（分钟）'), findsOneWidget);
    expect(find.text('云端实时更新'), findsOneWidget);
    expect(find.text('检查间隔（秒）'), findsOneWidget);
    expect(find.text('有效范围：5～3600 秒'), findsOneWidget);
    expect(find.text('30'), findsOneWidget);
  });

  testWidgets('updates theme, auto-save switch, and minute value',
      (tester) async {
    final settings = ValueNotifier(const AppSettings.defaults());
    addTearDown(settings.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: SettingsPage(
          settingsListenable: settings,
          onChanged: (value) => settings.value = value,
        ),
      ),
    );

    await tester.tap(find.text('深色模式'));
    await tester.pump();
    expect(settings.value.themeMode, ThemeMode.dark);

    await tester.enterText(find.byType(TextField).at(0), '99');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(settings.value.autoSaveMinutes, 60);

    final autoSaveSwitch = find.ancestor(
      of: find.text('自动保存'),
      matching: find.byType(SwitchListTile),
    );
    await tester.tap(autoSaveSwitch);
    await tester.pump();
    expect(settings.value.autoSaveEnabled, isFalse);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.labelText == '保存间隔（分钟）',
      ),
      findsNothing,
    );
  });

  testWidgets('renders WebDAV fields with an obscured password',
      (tester) async {
    final settings = ValueNotifier(const AppSettings.defaults());
    addTearDown(settings.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: SettingsPage(
          settingsListenable: settings,
          onChanged: (value) => settings.value = value,
          serviceFactory: (config) => WebDavService(
            config,
            gateway: _SettingsFakeGateway(),
          ),
        ),
      ),
    );

    await tester.drag(
      find.byType(Scrollable).first,
      const Offset(0, -500),
    );
    await tester.pump();
    expect(find.text('服务器地址'), findsOneWidget);
    final rootField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.labelText == '远程根目录',
    );
    await tester.scrollUntilVisible(
      rootField,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(rootField, findsOneWidget);
    final passwordField = tester.widget<TextField>(
      find.byWidgetPredicate(
        (widget) => widget is TextField && widget.obscureText,
      ),
    );
    expect(passwordField.obscureText, isTrue);
  });

  testWidgets('syncs WebDAV fields when settings load asynchronously',
      (tester) async {
    final settings = ValueNotifier(const AppSettings.defaults());
    addTearDown(settings.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: SettingsPage(
          settingsListenable: settings,
          onChanged: (value) => settings.value = value,
        ),
      ),
    );

    settings.value = settings.value.copyWith(
      webDav: const WebDavConfig(
        enabled: true,
        serverUrl: 'https://dav.example.com',
        username: 'alice',
        rootPath: '/notes',
        password: 'secret',
      ),
    );
    await tester.pump();

    await tester.drag(
      find.byType(Scrollable).first,
      const Offset(0, -500),
    );
    await tester.pump();

    final webDavSwitch = tester.widget<SwitchListTile>(
      find.ancestor(
        of: find.text('启用 WebDAV'),
        matching: find.byType(SwitchListTile),
      ),
    );
    expect(webDavSwitch.value, isTrue);

    final urlField = tester.widget<TextField>(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.labelText == '服务器地址',
      ),
    );
    expect(urlField.controller?.text, 'https://dav.example.com');
  });

  testWidgets('updates remote sync switch and interval', (tester) async {
    final settings = ValueNotifier(const AppSettings.defaults());
    addTearDown(settings.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: SettingsPage(
          settingsListenable: settings,
          onChanged: (value) => settings.value = value,
        ),
      ),
    );

    final syncSwitch = find.ancestor(
      of: find.text('云端实时更新'),
      matching: find.byType(SwitchListTile),
    );
    await tester.tap(syncSwitch);
    await tester.pump();
    expect(settings.value.remoteSyncEnabled, isFalse);

    final intervalField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.labelText == '检查间隔（秒）',
    );
    await tester.enterText(intervalField, '1');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(settings.value.remoteSyncSeconds, 5);
  });
}

class _SettingsFakeGateway implements WebDavGateway {
  @override
  Future<void> ping() async {}

  @override
  Future<List<WebDavEntry>> readDirectory(String path) async => [];

  @override
  Future<List<int>> readFile(String path) async => [];

  @override
  Future<void> writeFile(String path, List<int> bytes) async {}

  @override
  Future<void> makeDirectory(String path) async {}
}
