import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:md_editor/models/markdown_file.dart';
import 'package:md_editor/services/file_service.dart';

MarkdownFile _file(String path, {String? contentPath}) => MarkdownFile(
      path: path,
      contentPath: contentPath,
      name: 'test.md',
      content: 'hello',
      lastModified: DateTime(2026),
      size: 5,
    );

void main() {
  test('uses the DOCX extension when saving DOCX bytes', () {
    expect(
      FileService.exportFileName(
        defaultName: 'notes',
        mimeType:
            'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      ),
      'notes.docx',
    );
  });

  test('uses the HTML extension when saving HTML bytes', () {
    expect(
      FileService.exportFileName(
        defaultName: 'notes',
        mimeType: 'text/html',
      ),
      'notes.html',
    );
  });

  test('deletes an existing direct file but preserves cache', () async {
    final dir = await Directory.systemTemp.createTemp('md_delete_');
    addTearDown(() => dir.delete(recursive: true));
    final original = File('${dir.path}/original.md')
      ..writeAsStringSync('hello');
    final cache = File('${dir.path}/cache.md')..writeAsStringSync('hello');

    final result = await FileService.deleteOriginalFile(
      _file(original.path, contentPath: cache.path),
    );

    expect(result.status, FileDeletionStatus.success);
    expect(await original.exists(), isFalse);
    expect(await cache.exists(), isTrue);
  });

  test('returns notFound when direct file is absent', () async {
    final result = await FileService.deleteOriginalFile(
      _file('${Directory.systemTemp.path}/missing-original-md-file.md'),
    );

    expect(result.status, FileDeletionStatus.notFound);
  });

  test('rejects filename-only target', () async {
    final result = await FileService.deleteOriginalFile(_file('notes.md'));

    expect(result.status, FileDeletionStatus.invalidTarget);
  });

  test('rejects directory target', () async {
    final dir = await Directory.systemTemp.createTemp('md_delete_dir_');
    addTearDown(() => dir.delete(recursive: true));

    final result = await FileService.deleteOriginalFile(_file(dir.path));

    expect(result.status, FileDeletionStatus.invalidTarget);
    expect(await dir.exists(), isTrue);
  });

  test('cleans content cache separately', () async {
    final dir = await Directory.systemTemp.createTemp('md_cache_delete_');
    addTearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });
    final cache = File('${dir.path}/cache.md')..writeAsStringSync('hello');

    final deleted = await FileService.deleteCachedContent(_file(
      '${dir.path}/original.md',
      contentPath: cache.path,
    ));

    expect(deleted, isTrue);
    expect(await cache.exists(), isFalse);
  });
}
