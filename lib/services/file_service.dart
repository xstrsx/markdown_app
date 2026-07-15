import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import '../models/markdown_file.dart';

class PickResult {
  final String path;
  final String displayPath;
  final String? contentUri;
  final String name;

  PickResult({
    required this.path,
    required this.displayPath,
    this.contentUri,
    required this.name,
  });
}

enum FileDeletionStatus {
  success,
  notFound,
  permissionDenied,
  unsupported,
  invalidTarget,
  failed,
}

class FileDeletionResult {
  final FileDeletionStatus status;
  final String? message;

  const FileDeletionResult(this.status, {this.message});

  bool get isSuccess => status == FileDeletionStatus.success;
}

class FileService {
  static const _channel = MethodChannel('com.xstrsx.mdeditor/file');

  // ─── Permission ───────────────────────────────────────────────────────

  static Future<bool> ensureStoragePermission() async {
    if (!Platform.isAndroid) return true;

    var status = await Permission.manageExternalStorage.status;
    if (status.isGranted) return true;

    status = await Permission.manageExternalStorage.request();
    if (status.isGranted) return true;

    if (status.isPermanentlyDenied) {
      await openAppSettings();
    }
    return false;
  }

  // ─── Pick ─────────────────────────────────────────────────────────────

  static Future<PickResult?> pickMarkdownFile() async {
    if (Platform.isAndroid) {
      try {
        final result = await _channel.invokeMethod<Map>('pickFile', {
          'mimeTypes': ['text/markdown', 'text/plain', 'text/*'],
        });
        if (result == null) return null;
        final realPath = result['realPath'] as String? ?? '';
        final uri = result['uri'] as String? ?? '';
        final name = result['name'] as String? ?? 'unknown.md';

        // displayPath: real filesystem path if resolved, otherwise filename only
        final displayPath = realPath.isNotEmpty ? realPath : name;

        return PickResult(
          path: result['path'] as String,
          displayPath: displayPath,
          contentUri: uri.isNotEmpty ? uri : null,
          name: name,
        );
      } catch (e) {
        return null;
      }
    }

    // Desktop
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

  // ─── Read ─────────────────────────────────────────────────────────────

  static Future<MarkdownFile?> openFile(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) return null;
      return MarkdownFile.fromFile(file);
    } catch (e) {
      return null;
    }
  }

  /// Read file content from a content URI via platform channel.
  static Future<String?> readContentViaUri(String contentUri) async {
    if (!Platform.isAndroid) return null;
    try {
      return await _channel.invokeMethod<String>('readFile', {
        'uri': contentUri,
      });
    } catch (e) {
      return null;
    }
  }

  // ─── Save ─────────────────────────────────────────────────────────────

  static Future<bool> saveFile(String path, String content,
      {String? contentUri}) async {
    try {
      if (Platform.isAndroid && contentUri != null && contentUri.isNotEmpty) {
        await _channel.invokeMethod('writeToUri', {
          'uri': contentUri,
          'content': content,
        });
        // Also update local cache
        try {
          File(path).writeAsStringSync(content);
        } catch (_) {}
        return true;
      }
      final file = File(path);
      await file.writeAsString(content);
      return true;
    } catch (e) {
      return false;
    }
  }

  // ─── Save As ──────────────────────────────────────────────────────────

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
        final name = result['name'] as String? ?? defaultName;
        final displayPath = realPath.isNotEmpty ? realPath : name;
        return PickResult(
          path: result['path'] as String,
          displayPath: displayPath,
          contentUri: uri.isNotEmpty ? uri : null,
          name: name,
        );
      } catch (e) {
        return null;
      }
    }

    // Desktop
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

  // ─── Create / Share / Open location ───────────────────────────────────

  static Future<String> getDocumentsDirectory() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      return directory.path;
    } catch (e) {
      final directory = await getApplicationSupportDirectory();
      return directory.path;
    }
  }

  // ─── Local content cache (survives app restart) ────────────────────

  /// Persist content to a local cache file and return its path.
  /// [identifier] disambiguates files with the same name from different
  /// directories (e.g. content URI or display path).
  static Future<String> cacheContent(
      String content, String name, String? identifier) async {
    final dir = await getDocumentsDirectory();
    final cacheDir = Directory('$dir/cache');
    if (!await cacheDir.exists()) await cacheDir.create(recursive: true);
    // Stable filename: name + hash of identifier to prevent same-name collision
    final safeName = name.replaceAll(RegExp(r'[^\w.\-]'), '_');
    final idHash = (identifier ?? safeName).hashCode.toRadixString(16);
    final file = File('${cacheDir.path}/${safeName}_$idHash.md');
    await file.writeAsString(content);
    return file.path;
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

  /// Share the current content. On Android, writes to a temp file first
  /// since the "path" may be a content URI that share_plus can't handle.
  static Future<void> shareContent(String text, String name) async {
    try {
      final dir = await getDocumentsDirectory();
      final tempFile = File('$dir/$name');
      await tempFile.writeAsString(text);
      await Share.shareXFiles([XFile(tempFile.path)], text: '分享 Markdown 文件');
    } catch (e) {
      // Fallback: share as plain text
      await Share.share(text, subject: name);
    }
  }

  static Future<void> shareFile(String path) async {
    await Share.shareXFiles([XFile(path)], text: '分享 Markdown 文件');
  }

  static Future<void> openFileLocation(String path,
      {String? contentUri}) async {
    try {
      if (Platform.isAndroid) {
        await _channel.invokeMethod('openFileLocation', {
          'path': path,
          'contentUri': contentUri ?? '',
        });
      } else if (Platform.isWindows) {
        final result = await Process.run('explorer', ['/select,$path']);
        if (result.exitCode != 0) {
          final sep = path.lastIndexOf(RegExp(r'[/\\]'));
          final dir = sep >= 0 ? path.substring(0, sep) : path;
          await Process.run('explorer', [dir]);
        }
      } else if (Platform.isMacOS) {
        await Process.run('open', ['-R', path]);
      } else if (Platform.isLinux) {
        final sep = path.lastIndexOf('/');
        final dir = sep >= 0 ? path.substring(0, sep) : path;
        await Process.run('xdg-open', [dir]);
      }
    } catch (e) {
      await Clipboard.setData(ClipboardData(text: path));
    }
  }

  static Future<FileDeletionResult> deleteOriginalFile(
      MarkdownFile markdownFile) async {
    if (Platform.isAndroid &&
        markdownFile.contentUri != null &&
        markdownFile.contentUri!.isNotEmpty) {
      final uriResult = await _deleteAndroidDocument(markdownFile.contentUri!);
      if (uriResult.isSuccess || !_isValidDirectFilePath(markdownFile.path)) {
        return uriResult;
      }

      if (!await ensureStoragePermission()) {
        return const FileDeletionResult(
          FileDeletionStatus.permissionDenied,
          message: '没有删除原文件的权限',
        );
      }
    }

    if (!_isValidDirectFilePath(markdownFile.path)) {
      return const FileDeletionResult(
        FileDeletionStatus.invalidTarget,
        message: '无法确定原文件位置',
      );
    }

    final file = File(markdownFile.path);
    try {
      final type = await FileSystemEntity.type(markdownFile.path);
      if (type == FileSystemEntityType.notFound) {
        return const FileDeletionResult(FileDeletionStatus.notFound);
      }
      if (type != FileSystemEntityType.file) {
        return const FileDeletionResult(FileDeletionStatus.invalidTarget);
      }
      await file.delete();
      return const FileDeletionResult(FileDeletionStatus.success);
    } on FileSystemException catch (error) {
      final code = error.osError?.errorCode;
      if (code == 5 || code == 13) {
        return const FileDeletionResult(FileDeletionStatus.permissionDenied);
      }
      return FileDeletionResult(
        FileDeletionStatus.failed,
        message: error.message,
      );
    } catch (error) {
      return FileDeletionResult(
        FileDeletionStatus.failed,
        message: error.toString(),
      );
    }
  }

  static Future<FileDeletionResult> _deleteAndroidDocument(String uri) async {
    try {
      final raw =
          await _channel.invokeMethod<Map>('deleteDocument', {'uri': uri});
      final status = raw?['status'] as String?;
      return FileDeletionResult(
        switch (status) {
          'success' => FileDeletionStatus.success,
          'notFound' => FileDeletionStatus.notFound,
          'permissionDenied' => FileDeletionStatus.permissionDenied,
          'unsupported' => FileDeletionStatus.unsupported,
          _ => FileDeletionStatus.failed,
        },
        message: raw?['message'] as String?,
      );
    } on PlatformException catch (error) {
      return FileDeletionResult(
        FileDeletionStatus.failed,
        message: error.message,
      );
    }
  }

  static bool _isValidDirectFilePath(String path) {
    if (path.isEmpty || path.startsWith('content://')) return false;
    return File(path).isAbsolute;
  }

  static Future<bool> deleteCachedContent(MarkdownFile markdownFile) async {
    final path = markdownFile.contentPath;
    if (path == null || path.isEmpty) return true;
    try {
      final cacheFile = File(path);
      if (await cacheFile.exists()) await cacheFile.delete();
      return true;
    } catch (_) {
      return false;
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
