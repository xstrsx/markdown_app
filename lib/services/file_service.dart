import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/markdown_file.dart';

class PickResult {
  /// Local cache path for reading file content
  final String path;
  /// Resolved real path or URI string for display / history dedup
  final String displayPath;
  /// Android content URI for writing back via SAF
  final String? contentUri;
  /// File name
  final String name;

  PickResult({
    required this.path,
    required this.displayPath,
    this.contentUri,
    required this.name,
  });
}

class FileService {
  static const _channel = MethodChannel('com.xstrsx.mdeditor/file');

  static Future<PickResult?> pickMarkdownFile() async {
    if (Platform.isAndroid) {
      try {
        final result = await _channel.invokeMethod<Map>('pickFile', {
          'mimeTypes': ['text/markdown', 'text/plain', 'text/*'],
        });
        if (result == null) return null;
        final realPath = result['realPath'] as String? ?? '';
        final uri = result['uri'] as String? ?? '';
        return PickResult(
          path: result['path'] as String,
          displayPath: realPath.isNotEmpty ? realPath : uri,
          contentUri: uri.isNotEmpty ? uri : null,
          name: result['name'] as String? ?? 'unknown.md',
        );
      } catch (e) {
        return null;
      }
    }

    // Desktop: use file_picker
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['md', 'markdown', 'txt'],
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.single;
    if (file.path == null) return null;
    return PickResult(
      path: file.path!,
      displayPath: file.path!,
      name: file.name,
    );
  }

  static Future<MarkdownFile?> openFile(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) return null;
      return MarkdownFile.fromFile(file);
    } catch (e) {
      return null;
    }
  }

  /// Save text content to a file.
  /// On Android: writes back to the original URI if available.
  static Future<bool> saveFile(String path, String content,
      {String? contentUri}) async {
    try {
      if (Platform.isAndroid &&
          contentUri != null &&
          contentUri.isNotEmpty) {
        await _channel.invokeMethod('writeToUri', {
          'uri': contentUri,
          'content': content,
        });
        return true;
      }
      final file = File(path);
      await file.writeAsString(content);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Show "Save As" dialog.
  static Future<PickResult?> getSavePath({
    String defaultName = '未命名.md',
    String content = '',
  }) async {
    if (Platform.isAndroid) {
      try {
        final result = await _channel.invokeMethod<Map>('saveFileAs', {
          'fileName': defaultName,
          'content': content,
        });
        if (result == null) return null;
        final realPath = result['realPath'] as String? ?? '';
        final uri = result['uri'] as String? ?? '';
        return PickResult(
          path: result['path'] as String,
          displayPath: realPath.isNotEmpty ? realPath : uri,
          contentUri: uri.isNotEmpty ? uri : null,
          name: result['name'] as String? ?? defaultName,
        );
      } catch (e) {
        return null;
      }
    }

    // Desktop: use file_picker
    try {
      final bytes = Uint8List.fromList(utf8.encode(content));
      final outputPath = await FilePicker.platform.saveFile(
        dialogTitle: '保存 Markdown 文件',
        fileName: defaultName,
        type: FileType.any,
        bytes: bytes,
      );
      if (outputPath == null) return null;
      return PickResult(
        path: outputPath,
        displayPath: outputPath,
        name: outputPath.split(RegExp(r'[/\\]')).last,
      );
    } catch (e) {
      return null;
    }
  }

  static Future<String> getDocumentsDirectory() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      return directory.path;
    } catch (e) {
      final directory = await getApplicationSupportDirectory();
      return directory.path;
    }
  }

  static Future<String> createNewFile(String fileName) async {
    final docsDir = await getDocumentsDirectory();
    final filePath = '$docsDir/$fileName';
    final file = File(filePath);
    if (!await file.exists()) {
      await file.writeAsString('# $fileName\n\n开始编写 Markdown 内容...\n');
    }
    return filePath;
  }

  static Future<void> shareFile(String path) async {
    await Share.shareXFiles([XFile(path)], text: '分享 Markdown 文件');
  }

  static Future<void> openFileLocation(String path,
      {String? contentUri}) async {
    try {
      if (Platform.isAndroid) {
        await _channel.invokeMethod('openFileLocation', {'path': path});
        // On Android, the native side shows a Toast — no need for extra feedback
      } else if (Platform.isWindows) {
        final result = await Process.run('explorer', ['/select,$path']);
        if (result.exitCode != 0) {
          final dir = path.substring(0, path.lastIndexOf(RegExp(r'[/\\]')));
          await Process.run('explorer', [dir]);
        }
      } else if (Platform.isMacOS) {
        await Process.run('open', ['-R', path]);
      } else if (Platform.isLinux) {
        final dir = path.substring(0, path.lastIndexOf('/'));
        await Process.run('xdg-open', [dir]);
      }
    } catch (e) {
      await Clipboard.setData(ClipboardData(text: path));
    }
  }

  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
