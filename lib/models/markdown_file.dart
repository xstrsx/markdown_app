import 'dart:io';

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

  MarkdownFile({
    required this.path,
    this.contentUri,
    this.contentPath,
    required this.name,
    required this.content,
    required this.lastModified,
    required this.size,
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
  }) {
    return MarkdownFile(
      path: path ?? this.path,
      contentUri: contentUri ?? this.contentUri,
      contentPath: contentPath ?? this.contentPath,
      name: name ?? this.name,
      content: content ?? this.content,
      lastModified: lastModified ?? this.lastModified,
      size: size ?? this.size,
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
    };
  }

  factory MarkdownFile.fromJson(Map<String, dynamic> json) {
    final uri = json['contentUri'] as String?;
    final cp = json['contentPath'] as String?;
    return MarkdownFile(
      path: json['path'] as String,
      contentUri: (uri != null && uri.isNotEmpty) ? uri : null,
      contentPath: (cp != null && cp.isNotEmpty) ? cp : null,
      name: json['name'] as String,
      content: '',
      lastModified: DateTime.fromMillisecondsSinceEpoch(json['lastModified'] as int),
      size: json['size'] as int,
    );
  }
}
