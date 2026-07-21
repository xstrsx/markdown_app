import 'dart:io';

enum MarkdownStorageType { local, webDav }

class MarkdownFile {
  /// Display / real path or filename
  final String path;

  /// Android content URI for SAF write-back
  final String? contentUri;

  /// Path to a locally cached copy of the content (persistent, survives restarts)
  final String? contentPath;
  final String name;
  final String content;
  final DateTime lastModified;
  final int size;
  final MarkdownStorageType storageType;
  final String? remotePath;
  final DateTime? remoteModified;
  final int? remoteSize;

  MarkdownFile({
    required this.path,
    this.contentUri,
    this.contentPath,
    required this.name,
    required this.content,
    required this.lastModified,
    required this.size,
    this.storageType = MarkdownStorageType.local,
    this.remotePath,
    this.remoteModified,
    this.remoteSize,
  });

  factory MarkdownFile.fromFile(File file) {
    final stat = file.statSync();
    return MarkdownFile(
      path: file.path,
      name: file.uri.pathSegments.last,
      content: file.readAsStringSync(),
      lastModified: stat.modified,
      size: stat.size,
    );
  }

  factory MarkdownFile.fromPath(String path) {
    final file = File(path);
    return MarkdownFile.fromFile(file);
  }

  MarkdownFile copyWith({
    String? path,
    String? contentUri,
    String? contentPath,
    String? name,
    String? content,
    DateTime? lastModified,
    int? size,
    MarkdownStorageType? storageType,
    String? remotePath,
    DateTime? remoteModified,
    int? remoteSize,
  }) {
    return MarkdownFile(
      path: path ?? this.path,
      contentUri: contentUri ?? this.contentUri,
      contentPath: contentPath ?? this.contentPath,
      name: name ?? this.name,
      content: content ?? this.content,
      lastModified: lastModified ?? this.lastModified,
      size: size ?? this.size,
      storageType: storageType ?? this.storageType,
      remotePath: remotePath ?? this.remotePath,
      remoteModified: remoteModified ?? this.remoteModified,
      remoteSize: remoteSize ?? this.remoteSize,
    );
  }

  MarkdownFile withRemoteSnapshot({
    DateTime? modified,
    int? size,
  }) {
    return MarkdownFile(
      path: path,
      contentUri: contentUri,
      contentPath: contentPath,
      name: name,
      content: content,
      lastModified: lastModified,
      size: this.size,
      storageType: storageType,
      remotePath: remotePath,
      remoteModified: modified,
      remoteSize: size,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'path': path,
      'contentUri': contentUri ?? '',
      'contentPath': contentPath ?? '',
      'name': name,
      'lastModified': lastModified.millisecondsSinceEpoch,
      'size': size,
      'storageType': storageType.name,
      'remotePath': remotePath ?? '',
      'remoteModified': remoteModified?.millisecondsSinceEpoch,
      'remoteSize': remoteSize,
    };
  }

  factory MarkdownFile.fromJson(Map<String, dynamic> json) {
    final uri = json['contentUri'] as String?;
    final cp = json['contentPath'] as String?;
    final storageValue = json['storageType'] as String?;
    final remoteModifiedValue = json['remoteModified'] as int?;
    return MarkdownFile(
      path: json['path'] as String,
      contentUri: (uri != null && uri.isNotEmpty) ? uri : null,
      contentPath: (cp != null && cp.isNotEmpty) ? cp : null,
      name: json['name'] as String,
      content: '',
      lastModified:
          DateTime.fromMillisecondsSinceEpoch(json['lastModified'] as int),
      size: json['size'] as int,
      storageType: storageValue == MarkdownStorageType.webDav.name
          ? MarkdownStorageType.webDav
          : MarkdownStorageType.local,
      remotePath: (json['remotePath'] as String?)?.isNotEmpty == true
          ? json['remotePath'] as String
          : null,
      remoteModified: remoteModifiedValue == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(remoteModifiedValue),
      remoteSize: json['remoteSize'] as int?,
    );
  }
}
