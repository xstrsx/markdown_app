import 'package:flutter/foundation.dart';
import 'package:webdav_client/webdav_client.dart' as webdav;

import '../models/app_settings.dart';
import '../models/webdav_entry.dart';

abstract class WebDavGateway {
  Future<void> ping();

  Future<List<WebDavEntry>> readDirectory(String path);

  Future<List<int>> readFile(String path);

  Future<void> writeFile(String path, List<int> bytes);

  Future<void> makeDirectory(String path);
}

class WebDavException implements Exception {
  final String operation;
  final Object cause;

  const WebDavException(this.operation, this.cause);

  @override
  String toString() => 'WebDAV 操作失败: $operation';
}

class WebDavPathException implements Exception {
  final String path;

  const WebDavPathException(this.path);

  @override
  String toString() => 'WebDAV 路径超出远程根目录: $path';
}

class WebDavService {
  final WebDavConfig config;
  final WebDavGateway _gateway;
  late final String _rootPath;

  WebDavService(this.config, {WebDavGateway? gateway})
      : _gateway = gateway ?? WebDavClientGateway(config) {
    _rootPath = _normalizeAbsolute(config.rootPath);
  }

  String get rootPath => _rootPath;

  Future<void> testConnection() async {
    await _run('连接 WebDAV 服务器', _gateway.ping);
  }

  Future<List<WebDavEntry>> listDirectory(String path) async {
    final normalized = normalizePath(path);
    final entries = await _run(
      '读取远程目录',
      () => _gateway.readDirectory(normalized),
    );
    return entries
        .where((entry) => isWithinRoot(entry.path))
        .toList(growable: false);
  }

  Future<List<int>> download(String path) async {
    final normalized = normalizePath(path);
    return _run('下载远程文件', () => _gateway.readFile(normalized));
  }

  Future<void> upload(String path, List<int> bytes) async {
    final normalized = normalizePath(path);
    await _run(
      '上传远程文件',
      () => _gateway.writeFile(normalized, bytes),
    );
  }

  Future<void> makeDirectory(String path) async {
    final normalized = normalizePath(path);
    await _run(
      '创建远程目录',
      () => _gateway.makeDirectory(normalized),
    );
  }

  String normalizePath(String path) {
    final raw = path.trim().replaceAll('\\', '/');
    final absolute = raw.startsWith('/') ? raw : '$_rootPath/$raw';
    final normalized = _normalizeAbsolute(absolute);
    if (!isWithinRoot(normalized)) throw WebDavPathException(path);
    return normalized;
  }

  bool isWithinRoot(String path) {
    final normalized = _normalizeAbsolute(path);
    return _rootPath == '/' ||
        normalized == _rootPath ||
        normalized.startsWith('$_rootPath/');
  }

  static String _normalizeAbsolute(String path) {
    final parts = <String>[];
    for (final part in path.replaceAll('\\', '/').split('/')) {
      if (part.isEmpty || part == '.') continue;
      if (part == '..') {
        if (parts.isEmpty) throw WebDavPathException(path);
        parts.removeLast();
        continue;
      }
      parts.add(part);
    }
    return parts.isEmpty ? '/' : '/${parts.join('/')}';
  }

  Future<T> _run<T>(String operation, Future<T> Function() action) async {
    try {
      return await action();
    } on WebDavPathException {
      rethrow;
    } catch (error, stackTrace) {
      debugPrint('WebDAV $operation 失败: $error\n$stackTrace');
      throw WebDavException(operation, error);
    }
  }
}

class WebDavClientGateway implements WebDavGateway {
  final webdav.Client _client;

  WebDavClientGateway(WebDavConfig config)
      : _client = webdav.newClient(
          config.serverUrl.trim(),
          user: config.username,
          password: config.password,
        ) {
    _client.setConnectTimeout(15000);
    _client.setSendTimeout(30000);
    _client.setReceiveTimeout(30000);
  }

  @override
  Future<void> ping() => _client.ping();

  @override
  Future<List<WebDavEntry>> readDirectory(String path) async {
    final entries = await _client.readDir(path);
    return entries.map((entry) {
      final entryPath = entry.path ?? _join(path, entry.name ?? '');
      return WebDavEntry(
        name: entry.name ?? _nameOf(entryPath),
        path: entryPath,
        type: entry.isDir == true
            ? WebDavEntryType.directory
            : WebDavEntryType.file,
        size: entry.size,
        modified: entry.mTime,
      );
    }).toList(growable: false);
  }

  @override
  Future<List<int>> readFile(String path) => _client.read(path);

  @override
  Future<void> writeFile(String path, List<int> bytes) =>
      _client.write(path, Uint8List.fromList(bytes));

  @override
  Future<void> makeDirectory(String path) => _client.mkdirAll(path);

  static String _join(String directory, String name) {
    if (directory == '/') return '/$name';
    return '$directory/$name';
  }

  static String _nameOf(String path) {
    final clean =
        path.endsWith('/') ? path.substring(0, path.length - 1) : path;
    return clean.split('/').last;
  }
}
