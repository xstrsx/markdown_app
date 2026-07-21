import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';

class SettingsService {
  static const _themeModeKey = 'settings_theme_mode';
  static const _autoSaveEnabledKey = 'settings_auto_save_enabled';
  static const _autoSaveMinutesKey = 'settings_auto_save_minutes';
  static const _webDavEnabledKey = 'settings_webdav_enabled';
  static const _webDavUrlKey = 'settings_webdav_url';
  static const _webDavUsernameKey = 'settings_webdav_username';
  static const _webDavRootPathKey = 'settings_webdav_root_path';
  static const _webDavPasswordKey = 'settings_webdav_password';

  @visibleForTesting
  static Future<SharedPreferences> Function()? debugSharedPreferencesFactory;

  @visibleForTesting
  static SecureSettingsStore? debugSecureStorage;

  @visibleForTesting
  static void resetDebugSharedPreferencesFactory() {
    debugSharedPreferencesFactory = null;
    debugSecureStorage = null;
  }

  static Future<AppSettings> load() async {
    try {
      final prefs = await _getSharedPreferences();
      const defaults = AppSettings.defaults();
      final themeValue = prefs.getString(_themeModeKey);
      final webDavEnabled = prefs.getBool(_webDavEnabledKey) ?? false;
      final webDavUrl = prefs.getString(_webDavUrlKey) ?? '';
      final webDavUsername = prefs.getString(_webDavUsernameKey) ?? '';
      final webDavRootPath = prefs.getString(_webDavRootPathKey) ?? '/';
      var password = '';
      final hasWebDavConfiguration = webDavEnabled ||
          webDavUrl.trim().isNotEmpty ||
          webDavUsername.trim().isNotEmpty ||
          webDavRootPath.trim() != '/';
      if (hasWebDavConfiguration) {
        try {
          password = await _getSecureStorage().read(_webDavPasswordKey) ?? '';
        } catch (error, stackTrace) {
          debugPrint('读取 WebDAV 密码失败: $error\n$stackTrace');
        }
      }

      return AppSettings(
        themeMode: _themeModeFromString(themeValue ?? 'system'),
        autoSaveEnabled:
            prefs.getBool(_autoSaveEnabledKey) ?? defaults.autoSaveEnabled,
        autoSaveMinutes: normalizeMinutes(
          prefs.getInt(_autoSaveMinutesKey) ?? defaults.autoSaveMinutes,
        ),
        webDav: WebDavConfig(
          enabled: webDavEnabled,
          serverUrl: webDavUrl,
          username: webDavUsername,
          rootPath: webDavRootPath,
          password: password,
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
      try {
        await _getSecureStorage().write(
          _webDavPasswordKey,
          normalized.webDav.password,
        );
      } catch (error, stackTrace) {
        debugPrint('保存 WebDAV 密码失败: $error\n$stackTrace');
      }
      await prefs.setBool(_webDavEnabledKey, normalized.webDav.enabled);
      await prefs.setString(_webDavUrlKey, normalized.webDav.serverUrl.trim());
      await prefs.setString(_webDavUsernameKey, normalized.webDav.username);
      await prefs.setString(
        _webDavRootPathKey,
        normalized.webDav.rootPath.trim().isEmpty
            ? '/'
            : normalized.webDav.rootPath.trim(),
      );
    } catch (error, stackTrace) {
      debugPrint('保存应用设置失败: $error\n$stackTrace');
    }
  }

  static int normalizeMinutes(int value) => value.clamp(1, 60).toInt();

  static Future<SharedPreferences> _getSharedPreferences() {
    return debugSharedPreferencesFactory?.call() ??
        SharedPreferences.getInstance();
  }

  static SecureSettingsStore _getSecureStorage() {
    return debugSecureStorage ?? FlutterSecureSettingsStore();
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

abstract class SecureSettingsStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);
}

class FlutterSecureSettingsStore implements SecureSettingsStore {
  final FlutterSecureStorage _storage;

  FlutterSecureSettingsStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);
}
