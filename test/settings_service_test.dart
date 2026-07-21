import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:md_editor/models/app_settings.dart';
import 'package:md_editor/services/settings_service.dart';

void main() {
  tearDown(SettingsService.resetDebugSharedPreferencesFactory);

  test('defaults use system theme, enabled auto-save, and one minute', () {
    expect(
        const AppSettings.defaults(),
        const AppSettings(
          themeMode: ThemeMode.system,
          autoSaveEnabled: true,
          autoSaveMinutes: 1,
        ));
  });

  test('loads defaults when settings are absent', () async {
    SharedPreferences.setMockInitialValues({});

    expect(await SettingsService.load(), const AppSettings.defaults());
  });

  test('loads persisted settings and clamps minutes', () async {
    SharedPreferences.setMockInitialValues({
      'settings_theme_mode': 'dark',
      'settings_auto_save_enabled': false,
      'settings_auto_save_minutes': 99,
    });

    final settings = await SettingsService.load();
    expect(settings.themeMode, ThemeMode.dark);
    expect(settings.autoSaveEnabled, isFalse);
    expect(settings.autoSaveMinutes, 60);

    await SettingsService.save(settings.copyWith(autoSaveMinutes: 0));
    expect((await SettingsService.load()).autoSaveMinutes, 1);
  });

  test('falls back to defaults for an invalid theme value', () async {
    SharedPreferences.setMockInitialValues({
      'settings_theme_mode': 'unknown',
      'settings_auto_save_enabled': false,
      'settings_auto_save_minutes': 15,
    });

    expect(await SettingsService.load(), const AppSettings.defaults());
  });

  test('normalizes minutes to the supported range', () {
    expect(SettingsService.normalizeMinutes(-1), 1);
    expect(SettingsService.normalizeMinutes(1), 1);
    expect(SettingsService.normalizeMinutes(30), 30);
    expect(SettingsService.normalizeMinutes(99), 60);
  });

  test('does not throw when saving preferences fails', () async {
    SettingsService.debugSharedPreferencesFactory = () async {
      throw StateError('storage unavailable');
    };

    await expectLater(
      SettingsService.save(const AppSettings.defaults()),
      completes,
    );
  });
}
