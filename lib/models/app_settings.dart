import 'package:flutter/material.dart';

class AppSettings {
  final ThemeMode themeMode;
  final bool autoSaveEnabled;
  final int autoSaveMinutes;

  const AppSettings({
    required this.themeMode,
    required this.autoSaveEnabled,
    required this.autoSaveMinutes,
  });

  const AppSettings.defaults()
      : themeMode = ThemeMode.system,
        autoSaveEnabled = true,
        autoSaveMinutes = 1;

  AppSettings copyWith({
    ThemeMode? themeMode,
    bool? autoSaveEnabled,
    int? autoSaveMinutes,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      autoSaveEnabled: autoSaveEnabled ?? this.autoSaveEnabled,
      autoSaveMinutes: autoSaveMinutes ?? this.autoSaveMinutes,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppSettings &&
        other.themeMode == themeMode &&
        other.autoSaveEnabled == autoSaveEnabled &&
        other.autoSaveMinutes == autoSaveMinutes;
  }

  @override
  int get hashCode => Object.hash(themeMode, autoSaveEnabled, autoSaveMinutes);
}
