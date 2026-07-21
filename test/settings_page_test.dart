import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:md_editor/models/app_settings.dart';
import 'package:md_editor/pages/settings_page.dart';

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

    await tester.enterText(find.byType(TextField), '99');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(settings.value.autoSaveMinutes, 60);

    await tester.tap(find.byType(SwitchListTile));
    await tester.pump();
    expect(settings.value.autoSaveEnabled, isFalse);
    expect(find.byType(TextField), findsNothing);
  });
}
