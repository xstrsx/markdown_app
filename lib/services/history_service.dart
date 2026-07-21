import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/markdown_file.dart';

class HistoryService {
  static const String _historyKey = 'markdown_history';
  static const int _maxHistory = 50;

  static Future<List<MarkdownFile>> getHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getStringList(_historyKey) ?? [];
      final history = <MarkdownFile>[];
      for (final jsonStr in historyJson) {
        try {
          final decoded = jsonDecode(jsonStr);
          if (decoded is! Map<String, dynamic>) {
            throw const FormatException('历史记录不是对象');
          }
          history.add(MarkdownFile.fromJson(decoded));
        } catch (error, stackTrace) {
          debugPrint('跳过无效历史记录: $error\n$stackTrace');
        }
      }
      return history;
    } catch (error, stackTrace) {
      debugPrint('读取历史记录失败: $error\n$stackTrace');
      return [];
    }
  }

  static Future<void> addToHistory(MarkdownFile file) async {
    final history = await getHistory();

    history.removeWhere((f) => historyKey(f) == historyKey(file));

    // Add to beginning
    history.insert(0, file);

    // Trim to max size
    if (history.length > _maxHistory) {
      history.removeRange(_maxHistory, history.length);
    }

    await _saveHistory(history);
  }

  static Future<void> removeFromHistory(String path) async {
    final history = await getHistory();
    history.removeWhere(
      (f) => f.path == path || f.remotePath == path,
    );
    await _saveHistory(history);
  }

  static Future<void> removeFile(MarkdownFile file) async {
    final history = await getHistory();
    history.removeWhere((entry) => historyKey(entry) == historyKey(file));
    await _saveHistory(history);
  }

  static String historyKey(MarkdownFile file) {
    return file.storageType == MarkdownStorageType.webDav
        ? 'webdav:${file.remotePath ?? file.path}'
        : 'local:${file.path}';
  }

  static Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
  }

  static Future<List<MarkdownFile>> getRecentFiles({int limit = 3}) async {
    final history = await getHistory();
    return history.take(limit).toList();
  }

  static Future<void> _saveHistory(List<MarkdownFile> history) async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson =
        history.map((file) => jsonEncode(file.toJson())).toList();
    await prefs.setStringList(_historyKey, historyJson);
  }
}
