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
