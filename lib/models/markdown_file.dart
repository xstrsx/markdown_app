import 'dart:io';

class MarkdownFile {
  final String path;
  final String name;
  final String content;
  final DateTime lastModified;
  final int size;

  MarkdownFile({
    required this.path,
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
    String? name,
    String? content,
    DateTime? lastModified,
    int? size,
  }) {
    return MarkdownFile(
      path: path ?? this.path,
      name: name ?? this.name,
      content: content ?? this.content,
      lastModified: lastModified ?? this.lastModified,
      size: size ?? this.size,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'path': path,
      'name': name,
      'lastModified': lastModified.millisecondsSinceEpoch,
      'size': size,
    };
  }

  factory MarkdownFile.fromJson(Map<String, dynamic> json) {
    return MarkdownFile(
      path: json['path'] as String,
      name: json['name'] as String,
      content: '',
      lastModified: DateTime.fromMillisecondsSinceEpoch(json['lastModified'] as int),
      size: json['size'] as int,
    );
  }
}
