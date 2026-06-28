import 'dart:io';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/markdown_file.dart';

class FileService {
  static Future<String?> pickMarkdownFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['md', 'markdown', 'txt'],
    );
    if (result != null && result.files.single.path != null) {
      return result.files.single.path!;
    }
    return null;
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

  static Future<bool> saveFile(String path, String content) async {
    try {
      final file = File(path);
      await file.writeAsString(content);
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<String?> getSavePath({String defaultName = 'untitled.md'}) async {
    try {
      final outputPath = await FilePicker.platform.saveFile(
        dialogTitle: '保存 Markdown 文件',
        fileName: defaultName,
        type: FileType.custom,
        allowedExtensions: ['md'],
        lockParentWindow: true,
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

  /// 在文件管理器中打开文件所在位置，如果失败则将路径复制到剪贴板
  static Future<void> openFileLocation(String path) async {
    try {
      if (Platform.isWindows) {
        final result = await Process.run('explorer', ['/select,$path']);
        if (result.exitCode != 0) {
          // 如果 explorer 失败，尝试只打开父目录
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
