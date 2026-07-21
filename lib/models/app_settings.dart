import 'package:flutter/material.dart';

class WebDavConfig {
  final bool enabled;
  final String serverUrl;
  final String username;
  final String rootPath;
  final String password;

  const WebDavConfig({
    required this.enabled,
    required this.serverUrl,
    required this.username,
    required this.rootPath,
    required this.password,
  });

  const WebDavConfig.empty()
      : enabled = false,
        serverUrl = '',
        username = '',
        rootPath = '/',
        password = '';

  bool get isComplete {
    final uri = Uri.tryParse(serverUrl.trim());
    final root = rootPath.trim();
    if (!enabled ||
        uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        root.isEmpty ||
        !root.startsWith('/') ||
        root.contains('?') ||
        root.contains('#')) {
      return false;
    }

    var depth = 0;
    for (final segment in root.split('/')) {
      if (segment.isEmpty || segment == '.') continue;
      if (segment == '..') {
        if (depth == 0) return false;
        depth--;
      } else {
        depth++;
      }
    }
    return true;
  }

  WebDavConfig copyWith({
    bool? enabled,
    String? serverUrl,
    String? username,
    String? rootPath,
    String? password,
  }) {
    return WebDavConfig(
      enabled: enabled ?? this.enabled,
      serverUrl: serverUrl ?? this.serverUrl,
      username: username ?? this.username,
      rootPath: rootPath ?? this.rootPath,
      password: password ?? this.password,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WebDavConfig &&
        other.enabled == enabled &&
        other.serverUrl == serverUrl &&
        other.username == username &&
        other.rootPath == rootPath &&
        other.password == password;
  }

  @override
  int get hashCode => Object.hash(
        enabled,
        serverUrl,
        username,
        rootPath,
        password,
      );
}

class AppSettings {
  final ThemeMode themeMode;
  final bool autoSaveEnabled;
  final int autoSaveMinutes;
  final WebDavConfig webDav;
  final bool remoteSyncEnabled;
  final int remoteSyncSeconds;

  const AppSettings({
    required this.themeMode,
    required this.autoSaveEnabled,
    required this.autoSaveMinutes,
    this.webDav = const WebDavConfig.empty(),
    this.remoteSyncEnabled = true,
    this.remoteSyncSeconds = 30,
  });

  const AppSettings.defaults()
      : themeMode = ThemeMode.system,
        autoSaveEnabled = true,
        autoSaveMinutes = 1,
        webDav = const WebDavConfig.empty(),
        remoteSyncEnabled = true,
        remoteSyncSeconds = 30;

  AppSettings copyWith({
    ThemeMode? themeMode,
    bool? autoSaveEnabled,
    int? autoSaveMinutes,
    WebDavConfig? webDav,
    bool? remoteSyncEnabled,
    int? remoteSyncSeconds,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      autoSaveEnabled: autoSaveEnabled ?? this.autoSaveEnabled,
      autoSaveMinutes: autoSaveMinutes ?? this.autoSaveMinutes,
      webDav: webDav ?? this.webDav,
      remoteSyncEnabled: remoteSyncEnabled ?? this.remoteSyncEnabled,
      remoteSyncSeconds: remoteSyncSeconds ?? this.remoteSyncSeconds,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppSettings &&
        other.themeMode == themeMode &&
        other.autoSaveEnabled == autoSaveEnabled &&
        other.autoSaveMinutes == autoSaveMinutes &&
        other.webDav == webDav &&
        other.remoteSyncEnabled == remoteSyncEnabled &&
        other.remoteSyncSeconds == remoteSyncSeconds;
  }

  @override
  int get hashCode => Object.hash(
        themeMode,
        autoSaveEnabled,
        autoSaveMinutes,
        webDav,
        remoteSyncEnabled,
        remoteSyncSeconds,
      );
}
