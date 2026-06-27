import 'dart:io';
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
    final outputPath = await FilePicker.platform.saveFile(
      dialogTitle: '保存 Markdown 文件',
      fileName: defaultName,
      type: FileType.custom,
      allowedExtensions: ['md'],
    );
    return outputPath;
  }

  static Future<String> getDocumentsDirectory() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      return directory.path;
    } catch (e) {
      // Fallback for desktop
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

  static Future<void> openFileLocation(String path) async {
    // This is platform-specific
    // For desktop, we'd use the file manager
    // For mobile, we'd use a file explorer intent
    // For simplicity, we'll just share the file path info
    try {
      if (Platform.isWindows) {
        await Process.run('explorer', ['/select,', path]);
      } else if (Platform.isMacOS) {
        await Process.run('open', ['-R', path]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [path.substring(0, path.lastIndexOf('/'))]);
      }
    } catch (e) {
      // Ignore errors
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
