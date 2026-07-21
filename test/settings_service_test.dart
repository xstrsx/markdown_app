import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:md_editor/models/app_settings.dart';
import 'package:md_editor/services/settings_service.dart';

class FakeSecureSettingsStore implements SecureSettingsStore {
  final Map<String, String> values;

  FakeSecureSettingsStore([Map<String, String>? initialValues])
      : values = {...?initialValues};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}

void main() {
  setUp(() {
    SettingsService.debugSecureStorage = FakeSecureSettingsStore();
  });

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

  test('uses safe WebDAV defaults when configuration is absent', () async {
    SharedPreferences.setMockInitialValues({});

    final settings = await SettingsService.load();

    expect(settings.webDav, const WebDavConfig.empty());
    expect(settings.webDav.isComplete, isFalse);
  });

  test('loads WebDAV settings and reads the password securely', () async {
    SharedPreferences.setMockInitialValues({
      'settings_webdav_enabled': true,
      'settings_webdav_url': 'https://dav.example.com',
      'settings_webdav_username': 'alice',
      'settings_webdav_root_path': '/notes',
    });
    SettingsService.debugSecureStorage = FakeSecureSettingsStore({
      'settings_webdav_password': 'secret',
    });

    final settings = await SettingsService.load();

    expect(settings.webDav.isComplete, isTrue);
    expect(settings.webDav.password, 'secret');
  });

  test('rejects invalid WebDAV URLs and root paths', () {
    expect(
      const WebDavConfig(
        enabled: true,
        serverUrl: 'ftp://dav.example.com',
        username: '',
        rootPath: '/notes',
        password: '',
      ).isComplete,
      isFalse,
    );
    expect(
      const WebDavConfig(
        enabled: true,
        serverUrl: 'https://dav.example.com',
        username: '',
        rootPath: 'notes',
        password: '',
      ).isComplete,
      isFalse,
    );
  });

  test('saves WebDAV password through secure storage', () async {
    SharedPreferences.setMockInitialValues({});
    final secureStore = FakeSecureSettingsStore();
    SettingsService.debugSecureStorage = secureStore;
    const webDav = WebDavConfig(
      enabled: true,
      serverUrl: 'https://dav.example.com',
      username: 'alice',
      rootPath: '/notes',
      password: 'secret',
    );

    await SettingsService.save(
      const AppSettings.defaults().copyWith(webDav: webDav),
    );

    expect(secureStore.values['settings_webdav_password'], 'secret');
  });

  test('does not throw when secure WebDAV storage fails', () async {
    SharedPreferences.setMockInitialValues({});
    SettingsService.debugSecureStorage = _ThrowingSecureSettingsStore();

    await expectLater(
      SettingsService.save(const AppSettings.defaults()),
      completes,
    );
  });
}

class _ThrowingSecureSettingsStore implements SecureSettingsStore {
  @override
  Future<String?> read(String key) async => throw StateError('secure read');

  @override
  Future<void> write(String key, String value) async =>
      throw StateError('secure write');
}
