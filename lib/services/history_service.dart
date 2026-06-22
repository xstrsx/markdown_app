import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/markdown_file.dart';

class HistoryService {
  static const String _historyKey = 'markdown_history';
  static const int _maxHistory = 50;

  static Future<List<MarkdownFile>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getStringList(_historyKey) ?? [];
    return historyJson
        .map((jsonStr) => MarkdownFile.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>))
        .toList();
  }

  static Future<void> addToHistory(MarkdownFile file) async {
    final history = await getHistory();
    
    // Remove existing entry with same path
    history.removeWhere((f) => f.path == file.path);
    
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
    history.removeWhere((f) => f.path == path);
    await _saveHistory(history);
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
    final historyJson = history
        .map((file) => jsonEncode(file.toJson()))
        .toList();
    await prefs.setStringList(_historyKey, historyJson);
  }
}
