import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';

class SettingsService {
  static const _themeModeKey = 'settings_theme_mode';
  static const _autoSaveEnabledKey = 'settings_auto_save_enabled';
  static const _autoSaveMinutesKey = 'settings_auto_save_minutes';

  @visibleForTesting
  static Future<SharedPreferences> Function()? debugSharedPreferencesFactory;

  @visibleForTesting
  static void resetDebugSharedPreferencesFactory() {
    debugSharedPreferencesFactory = null;
  }

  static Future<AppSettings> load() async {
    try {
      final prefs = await _getSharedPreferences();
      const defaults = AppSettings.defaults();
      final themeValue = prefs.getString(_themeModeKey);

      return AppSettings(
        themeMode: _themeModeFromString(themeValue ?? 'system'),
        autoSaveEnabled:
            prefs.getBool(_autoSaveEnabledKey) ?? defaults.autoSaveEnabled,
        autoSaveMinutes: normalizeMinutes(
          prefs.getInt(_autoSaveMinutesKey) ?? defaults.autoSaveMinutes,
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('读取应用设置失败: $error\n$stackTrace');
      return const AppSettings.defaults();
    }
  }

  static Future<void> save(AppSettings settings) async {
    final normalized = settings.copyWith(
      autoSaveMinutes: normalizeMinutes(settings.autoSaveMinutes),
    );

    try {
      final prefs = await _getSharedPreferences();
      final themeSaved = await prefs.setString(
        _themeModeKey,
        _themeModeToString(normalized.themeMode),
      );
      final autoSaveEnabledSaved = await prefs.setBool(
        _autoSaveEnabledKey,
        normalized.autoSaveEnabled,
      );
      final minutesSaved = await prefs.setInt(
        _autoSaveMinutesKey,
        normalized.autoSaveMinutes,
      );

      if (!themeSaved || !autoSaveEnabledSaved || !minutesSaved) {
        debugPrint(
          '保存应用设置失败: theme=$themeSaved, '
          'autoSaveEnabled=$autoSaveEnabledSaved, minutes=$minutesSaved',
        );
      }
    } catch (error, stackTrace) {
      debugPrint('保存应用设置失败: $error\n$stackTrace');
    }
  }

  static int normalizeMinutes(int value) => value.clamp(1, 60).toInt();

  static Future<SharedPreferences> _getSharedPreferences() {
    return debugSharedPreferencesFactory?.call() ??
        SharedPreferences.getInstance();
  }

  static ThemeMode _themeModeFromString(String value) {
    return switch (value) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      'system' => ThemeMode.system,
      _ => throw FormatException('未知主题模式: $value'),
    };
  }

  static String _themeModeToString(ThemeMode themeMode) {
    return switch (themeMode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
  }
}
