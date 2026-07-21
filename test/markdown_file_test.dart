import 'package:flutter_test/flutter_test.dart';

import 'package:md_editor/models/markdown_file.dart';

void main() {
  test('old history JSON remains a local file', () {
    final file = MarkdownFile.fromJson({
      'path': 'C:/notes/a.md',
      'contentUri': '',
      'contentPath': '',
      'name': 'a.md',
      'lastModified': 0,
      'size': 4,
    });

    expect(file.storageType, MarkdownStorageType.local);
    expect(file.remotePath, isNull);
  });

  test('cloud metadata round-trips through history JSON', () {
    final file = MarkdownFile(
      path: '/notes/a.md',
      name: 'a.md',
      content: '# A',
      lastModified: DateTime.fromMillisecondsSinceEpoch(1000),
      size: 3,
      storageType: MarkdownStorageType.webDav,
      remotePath: '/notes/a.md',
    );

    final restored = MarkdownFile.fromJson(file.toJson());

    expect(restored.storageType, MarkdownStorageType.webDav);
    expect(restored.remotePath, '/notes/a.md');
    expect(restored.path, '/notes/a.md');
  });
}
