import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:md_editor/models/app_settings.dart';
import 'package:md_editor/models/webdav_entry.dart';
import 'package:md_editor/services/webdav_service.dart';

const testConfig = WebDavConfig(
  enabled: true,
  serverUrl: 'https://dav.example.com',
  username: 'alice',
  rootPath: '/notes',
  password: 'secret',
);

class FakeWebDavGateway implements WebDavGateway {
  final Map<String, List<int>> files;
  final Map<String, List<WebDavEntry>> directories;
  bool shouldFail = false;

  FakeWebDavGateway({
    Map<String, List<int>>? initialFiles,
    Map<String, List<WebDavEntry>>? initialDirectories,
  })  : files = {...?initialFiles},
        directories = {...?initialDirectories};

  @override
  Future<void> ping() async {
    _checkFailure();
  }

  @override
  Future<List<WebDavEntry>> readDirectory(String path) async {
    _checkFailure();
    return directories[path] ?? [];
  }

  @override
  Future<List<int>> readFile(String path) async {
    _checkFailure();
    final value = files[path];
    if (value == null) throw StateError('missing file');
    return [...value];
  }

  @override
  Future<void> writeFile(String path, List<int> bytes) async {
    _checkFailure();
    files[path] = [...bytes];
  }

  @override
  Future<void> makeDirectory(String path) async {
    _checkFailure();
    directories.putIfAbsent(path, () => []);
  }

  void _checkFailure() {
    if (shouldFail) throw StateError('network unavailable');
  }
}

void main() {
  test('normalizes paths and rejects traversal outside the root', () {
    final service = WebDavService(testConfig, gateway: FakeWebDavGateway());

    expect(service.normalizePath('/notes/sub/../todo.md'), '/notes/todo.md');
    expect(
      () => service.normalizePath('/notes/../../outside.md'),
      throwsA(isA<WebDavPathException>()),
    );
  });

  test('trims the configured root path before using it', () {
    final service = WebDavService(
      testConfig.copyWith(rootPath: '  /notes  '),
      gateway: FakeWebDavGateway(),
    );

    expect(service.rootPath, '/notes');
  });

  test('uploads and downloads UTF-8 bytes through the gateway', () async {
    final gateway = FakeWebDavGateway();
    final service = WebDavService(testConfig, gateway: gateway);

    await service.upload('/notes/a.md', utf8.encode('# 标题'));

    expect(utf8.decode(await service.download('/notes/a.md')), '# 标题');
  });

  test('lists entries within the configured root', () async {
    final gateway = FakeWebDavGateway(
      initialDirectories: {
        '/notes': [
          const WebDavEntry(
            name: 'sub',
            path: '/notes/sub',
            type: WebDavEntryType.directory,
          ),
          const WebDavEntry(
            name: 'a.md',
            path: '/notes/a.md',
            type: WebDavEntryType.file,
          ),
        ],
      },
    );
    final service = WebDavService(testConfig, gateway: gateway);

    final entries = await service.listDirectory('/notes');

    expect(entries.map((entry) => entry.name), ['sub', 'a.md']);
  });

  test('reads remote file metadata from its parent directory', () async {
    final modified = DateTime(2026, 7, 21, 10, 30);
    final gateway = FakeWebDavGateway(
      initialDirectories: {
        '/notes': [
          WebDavEntry(
            name: 'a.md',
            path: '/notes/a.md',
            type: WebDavEntryType.file,
            size: 12,
            modified: modified,
          ),
        ],
      },
    );
    final service = WebDavService(testConfig, gateway: gateway);

    final metadata = await service.getMetadata('/notes/a.md');

    expect(metadata?.modified, modified);
    expect(metadata?.size, 12);
  });

  test('converts gateway failures to a safe WebDAV exception', () async {
    final gateway = FakeWebDavGateway()..shouldFail = true;
    final service = WebDavService(testConfig, gateway: gateway);

    await expectLater(
        service.testConnection(), throwsA(isA<WebDavException>()));
    expect(
      () => service.normalizePath('/outside.md'),
      throwsA(isA<WebDavPathException>()),
    );
  });
}
