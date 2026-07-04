import 'dart:io';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/markdown_file.dart';

class PickResult {
  final String path;
  final String? contentUri;

  PickResult({required this.path, this.contentUri});
}

class FileService {
  static const _channel = MethodChannel('com.xstrsx.mdeditor/file');

  /// Pick a markdown file. On Android, also captures the original content URI
  /// so we can write back to the original file location.
  static Future<PickResult?> pickMarkdownFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['md', 'markdown', 'txt'],
      withData: false,
    );
    if (result == null || result.files.isEmpty) return null;

    final file = result.files.single;
    if (file.path == null) return null;

    return PickResult(
      path: file.path!,
      contentUri: Platform.isAndroid ? file.identifier : null,
    );
  }

  static Future<MarkdownFile?> openFile(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) {
        return null;
      }
      return MarkdownFile.fromFile(file);
    } catch (e) {
      return null;
    }
  }

  /// Save text content to a file path.
  /// On Android with a content URI, writes back to the original file via SAF.
  static Future<bool> saveFile(String path, String content,
      {String? contentUri}) async {
    try {
      if (Platform.isAndroid && contentUri != null && contentUri.isNotEmpty) {
        // Write back to original file via content URI
        final result = await _channel.invokeMethod<bool>('writeToUri', {
          'uri': contentUri,
          'content': content,
        });
        if (result == true) return true;
        // Fallback: try resolving real path and writing directly
        final realPath =
            await _channel.invokeMethod<String>('getRealPath', {
          'uri': contentUri,
        });
        if (realPath != null && realPath.isNotEmpty) {
          final file = File(realPath);
          await file.writeAsString(content);
          return true;
        }
        return false;
      }
      // Desktop / direct file path
      final file = File(path);
      await file.writeAsString(content);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Show a "Save As" dialog. On Android uses file_picker's saveFile.
  static Future<String?> getSavePath({String defaultName = '未命名.md'}) async {
    try {
      final outputPath = await FilePicker.platform.saveFile(
        dialogTitle: '保存 Markdown 文件',
        fileName: defaultName,
        type: FileType.any,
        bytes: null,
      );
      return outputPath;
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

  /// Open the file's parent folder in the platform file manager.
  static Future<void> openFileLocation(String path,
      {String? contentUri}) async {
    try {
      if (Platform.isAndroid) {
        // Use Android intent via MethodChannel
        await _channel.invokeMethod('openFileLocation', {
          'path': path,
          'uri': contentUri ?? '',
        });
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
      // Fallback: copy path to clipboard
      await Clipboard.setData(ClipboardData(text: path));
    }
  }

  static String formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }
}
