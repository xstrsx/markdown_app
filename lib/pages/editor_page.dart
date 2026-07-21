import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/app_settings.dart';
import '../models/markdown_file.dart';
import '../models/webdav_entry.dart';
import '../services/file_service.dart';
import '../services/history_service.dart';
import '../services/pdf_export_service.dart';
import '../services/settings_service.dart';
import '../services/webdav_service.dart';
import '../widgets/editor_toolbar.dart';
import '../widgets/markdown_preview.dart';
import '../widgets/storage_choice_dialog.dart';
import 'webdav_file_picker_page.dart';

bool contentChangedSinceSave(String savedContent, String currentContent) =>
    savedContent != currentContent;

Duration? autoSaveDuration({required bool enabled, required int minutes}) {
  if (!enabled) return null;
  return Duration(minutes: SettingsService.normalizeMinutes(minutes));
}

Duration? remoteSyncDuration({
  required bool enabled,
  required bool webDavConfigured,
  required int seconds,
}) {
  if (!enabled || !webDavConfigured) return null;
  return Duration(
    seconds: SettingsService.normalizeRemoteSyncSeconds(seconds),
  );
}

bool remoteSnapshotChanged({
  required DateTime? baselineModified,
  required int? baselineSize,
  required DateTime? remoteModified,
  required int? remoteSize,
}) {
  if (baselineModified == null && baselineSize == null) return false;
  return baselineModified != remoteModified || baselineSize != remoteSize;
}

bool remoteReloadConflict({
  required bool localModified,
  required String expectedContent,
  required String currentContent,
}) {
  return localModified || expectedContent != currentContent;
}

enum CloudConflictResolution { keepLocal, loadRemote, cancel }

class EditorPage extends StatefulWidget {
  final MarkdownFile? file;
  final String? initialFilePath;
  final String? initialDisplayPath;
  final String? initialContentUri;
  final String? initialName;
  final bool exportPdfOnOpen;
  final bool autoSaveEnabled;
  final int autoSaveMinutes;
  final ValueListenable<AppSettings>? settingsListenable;
  final WebDavService Function(WebDavConfig config)? webDavServiceFactory;
  final Future<String> Function(
      String content, String name, String? identifier)? cacheContent;

  const EditorPage({
    super.key,
    this.file,
    this.initialFilePath,
    this.initialDisplayPath,
    this.initialContentUri,
    this.initialName,
    this.exportPdfOnOpen = false,
    this.autoSaveEnabled = true,
    this.autoSaveMinutes = 1,
    this.settingsListenable,
    this.webDavServiceFactory,
    this.cacheContent,
  });

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage>
    with SingleTickerProviderStateMixin {
  late TextEditingController _textController;
  late TabController _tabController;
  late ScrollController _editorScrollController;
  late ScrollController _previewScrollController;

  MarkdownFile? _currentFile;
  String? _contentUri;
  String? _cachePath;
  bool _isModified = false;
  bool _isLoadingInitialFile = true;
  Timer? _autoSaveTimer;
  Timer? _remoteSyncTimer;
  bool _isSaving = false;
  bool _isCheckingRemote = false;
  bool _remoteConflict = false;
  bool _isExportingPdf = false;
  late bool _autoSaveEnabled;
  late int _autoSaveMinutes;
  late bool _remoteSyncEnabled;
  late int _remoteSyncSeconds;
  late WebDavConfig _webDavConfig;
  DateTime? _remoteModified;
  int? _remoteSize;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    _editorScrollController = ScrollController();
    _previewScrollController = ScrollController();
    _tabController = TabController(length: 2, vsync: this);
    _autoSaveEnabled = widget.settingsListenable?.value.autoSaveEnabled ??
        widget.autoSaveEnabled;
    _autoSaveMinutes = SettingsService.normalizeMinutes(
      widget.settingsListenable?.value.autoSaveMinutes ??
          widget.autoSaveMinutes,
    );
    _remoteSyncEnabled =
        widget.settingsListenable?.value.remoteSyncEnabled ?? true;
    _remoteSyncSeconds = SettingsService.normalizeRemoteSyncSeconds(
      widget.settingsListenable?.value.remoteSyncSeconds ?? 30,
    );
    _webDavConfig =
        widget.settingsListenable?.value.webDav ?? const WebDavConfig.empty();
    widget.settingsListenable?.addListener(_onSettingsChanged);
    _loadInitialFile();
    _setupAutoSave();
  }

  void _onSettingsChanged() {
    final settings = widget.settingsListenable?.value;
    if (settings == null || !mounted) return;
    final changed = _autoSaveEnabled != settings.autoSaveEnabled ||
        _autoSaveMinutes != settings.autoSaveMinutes ||
        _remoteSyncEnabled != settings.remoteSyncEnabled ||
        _remoteSyncSeconds != settings.remoteSyncSeconds ||
        _webDavConfig != settings.webDav;
    if (!changed) return;

    setState(() {
      _autoSaveEnabled = settings.autoSaveEnabled;
      _autoSaveMinutes = SettingsService.normalizeMinutes(
        settings.autoSaveMinutes,
      );
      _remoteSyncEnabled = settings.remoteSyncEnabled;
      _remoteSyncSeconds = SettingsService.normalizeRemoteSyncSeconds(
        settings.remoteSyncSeconds,
      );
      _webDavConfig = settings.webDav;
    });
    _autoSaveTimer?.cancel();
    if (_isModified) _scheduleAutoSave();
    _restartRemoteSync();
  }

  Future<void> _loadInitialFile() async {
    try {
      if (widget.file != null) {
        final file = widget.file!;
        _currentFile = file;
        _contentUri = file.contentUri;
        _cachePath = file.contentPath;
        _remoteModified = file.remoteModified;
        _remoteSize = file.remoteSize;

        var content = file.content;
        if (content.isEmpty) {
          content = await _loadContent(
            file.contentPath,
            file.path,
            _contentUri,
          );
        }
        _textController.text = content;
        _isModified = false;
        if (mounted) setState(() {});
        await HistoryService.addToHistory(file.copyWith(content: content));
        _restartRemoteSync();
        if (widget.exportPdfOnOpen) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _exportPdf();
          });
        }
        return;
      }

      if (widget.initialFilePath != null) {
        final cachePath = widget.initialFilePath!;
        final loaded = await FileService.openFile(cachePath);
        if (loaded != null) {
          final displayPath = widget.initialDisplayPath ?? loaded.path;
          final contentUri = widget.initialContentUri;
          final name = widget.initialName ?? loaded.name;
          final text = loaded.content;

          final id = contentUri ?? displayPath;
          final contentPath = await FileService.cacheContent(text, name, id);

          final updatedFile = MarkdownFile(
            path: displayPath,
            contentUri: contentUri,
            contentPath: contentPath,
            name: name,
            content: text,
            lastModified: loaded.lastModified,
            size: loaded.size,
          );
          if (!mounted) return;
          setState(() {
            _currentFile = updatedFile;
            _contentUri = contentUri;
            _cachePath = cachePath;
            _textController.text = text;
            _isModified = false;
          });
          await HistoryService.addToHistory(updatedFile);
          if (widget.exportPdfOnOpen && mounted) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _exportPdf();
            });
          }
        }
      }
    } catch (error, stackTrace) {
      debugPrint('加载初始 Markdown 文件失败: $error\n$stackTrace');
    } finally {
      _isLoadingInitialFile = false;
    }
  }

  Future<String> _loadContent(
      String? contentPath, String? filePath, String? contentUri) async {
    if (contentPath != null && contentPath.isNotEmpty) {
      try {
        final f = File(contentPath);
        if (await f.exists()) {
          return await f.readAsString();
        }
      } catch (_) {}
    }

    if (filePath != null &&
        filePath.isNotEmpty &&
        !filePath.startsWith('content://')) {
      try {
        final f = File(filePath);
        if (await f.exists()) {
          return await f.readAsString();
        }
      } catch (_) {}
    }

    if (contentUri != null && contentUri.isNotEmpty) {
      final text = await FileService.readContentViaUri(contentUri);
      if (text != null) return text;
    }

    return '';
  }

  void _setupAutoSave() {
    _textController.addListener(() {
      if (_isLoadingInitialFile || !mounted) return;
      if (!_isModified) setState(() => _isModified = true);
      _scheduleAutoSave();
    });
  }

  void _scheduleAutoSave() {
    _autoSaveTimer?.cancel();
    final duration = autoSaveDuration(
      enabled: _autoSaveEnabled,
      minutes: _autoSaveMinutes,
    );
    if (duration != null) _autoSaveTimer = Timer(duration, _autoSave);
  }

  void _restartRemoteSync() {
    _remoteSyncTimer?.cancel();
    _remoteSyncTimer = null;

    final file = _currentFile;
    final settings = widget.settingsListenable?.value;
    final config = settings?.webDav;
    if (file == null ||
        file.storageType != MarkdownStorageType.webDav ||
        config == null) {
      return;
    }

    final duration = remoteSyncDuration(
      enabled: _remoteSyncEnabled,
      webDavConfigured: config.isComplete,
      seconds: _remoteSyncSeconds,
    );
    if (duration == null) return;

    _remoteSyncTimer = Timer.periodic(duration, (_) {
      unawaited(_checkRemoteChanges());
    });
  }

  bool get _hasRemoteSnapshot => _remoteModified != null || _remoteSize != null;

  Future<void> _checkRemoteChanges() async {
    if (_isCheckingRemote ||
        _isSaving ||
        _remoteConflict ||
        !mounted ||
        _currentFile?.storageType != MarkdownStorageType.webDav) {
      return;
    }
    final file = _currentFile;
    final config = widget.settingsListenable?.value.webDav;
    final remotePath = file?.remotePath;
    if (file == null ||
        config == null ||
        !config.isComplete ||
        remotePath == null) {
      return;
    }

    _isCheckingRemote = true;
    try {
      final service =
          widget.webDavServiceFactory?.call(config) ?? WebDavService(config);
      final metadata = await service.getMetadata(remotePath);
      if (!mounted || _currentFile?.remotePath != remotePath) return;

      if (!_hasRemoteSnapshot) {
        _applyRemoteSnapshot(metadata);
        return;
      }

      final changed = metadata == null ||
          remoteSnapshotChanged(
            baselineModified: _remoteModified,
            baselineSize: _remoteSize,
            remoteModified: metadata.modified,
            remoteSize: metadata.size,
          );
      if (!changed) return;

      if (_isModified) {
        await _resolveRemoteConflict(service, metadata);
      } else if (metadata != null) {
        await _reloadRemoteFile(
          service,
          metadata,
          expectedContent: _textController.text,
        );
      } else {
        _remoteConflict = true;
        _autoSaveTimer?.cancel();
        _showRemoteMessage('云端文件已不存在，已暂停自动同步');
      }
    } catch (error, stackTrace) {
      debugPrint('检查云端文件更新失败: $error\n$stackTrace');
      if (mounted) _showRemoteMessage('检查云端文件更新失败，请检查网络');
    } finally {
      _isCheckingRemote = false;
    }
  }

  void _applyRemoteSnapshot(WebDavEntry? metadata) {
    final file = _currentFile;
    if (file == null) return;
    _remoteModified = metadata?.modified;
    _remoteSize = metadata?.size;
    _currentFile = file.withRemoteSnapshot(
      modified: _remoteModified,
      size: _remoteSize,
    );
    if (mounted) setState(() {});
  }

  Future<void> _reloadRemoteFile(
    WebDavService service,
    WebDavEntry metadata, {
    String? expectedContent,
    bool allowLocalOverwrite = false,
  }) async {
    final file = _currentFile;
    final remotePath = file?.remotePath;
    if (file == null || remotePath == null) return;

    final contentBeforeReload = _textController.text;
    if (!allowLocalOverwrite &&
        expectedContent != null &&
        remoteReloadConflict(
          localModified: _isModified,
          expectedContent: expectedContent,
          currentContent: contentBeforeReload,
        )) {
      await _resolveRemoteConflict(service, metadata);
      return;
    }

    final content = utf8.decode(await service.download(remotePath));
    final contentPath = await _cacheContent(
      content,
      file.name,
      'webdav:$remotePath',
    );
    if (!allowLocalOverwrite &&
        remoteReloadConflict(
          localModified: _isModified,
          expectedContent: contentBeforeReload,
          currentContent: _textController.text,
        )) {
      await _resolveRemoteConflict(service, metadata);
      return;
    }
    final updatedFile = file
        .copyWith(
          content: content,
          contentPath: contentPath,
          lastModified: DateTime.now(),
          size: content.length,
        )
        .withRemoteSnapshot(
          modified: metadata.modified,
          size: metadata.size,
        );
    _isLoadingInitialFile = true;
    _textController.text = content;
    _isLoadingInitialFile = false;
    _remoteModified = metadata.modified;
    _remoteSize = metadata.size;
    _remoteConflict = false;
    if (!mounted) return;
    setState(() {
      _currentFile = updatedFile;
      _isModified = false;
    });
    await HistoryService.addToHistory(updatedFile);
    _restartRemoteSync();
  }

  Future<void> _resolveRemoteConflict(
    WebDavService service,
    WebDavEntry? metadata,
  ) async {
    _remoteConflict = true;
    _autoSaveTimer?.cancel();
    final resolution = await showDialog<CloudConflictResolution>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('检测到云端文件已更新'),
        content: const Text('其他设备已经修改了此文件，请选择如何处理当前修改。'),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(CloudConflictResolution.cancel),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: metadata == null
                ? null
                : () => Navigator.of(context)
                    .pop(CloudConflictResolution.loadRemote),
            child: const Text('加载云端版本'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(CloudConflictResolution.keepLocal),
            child: const Text('保留本地并覆盖'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    switch (resolution) {
      case CloudConflictResolution.keepLocal:
        _remoteConflict = false;
        await _saveCloudFile(forceRemoteOverwrite: true);
      case CloudConflictResolution.loadRemote:
        if (metadata == null) return;
        try {
          await _reloadRemoteFile(
            service,
            metadata,
            allowLocalOverwrite: true,
          );
        } catch (error, stackTrace) {
          debugPrint('加载冲突云端版本失败: $error\n$stackTrace');
          if (mounted) _showRemoteMessage('加载云端版本失败，请稍后重试');
        }
      case CloudConflictResolution.cancel:
      case null:
        break;
    }
  }

  void _showRemoteMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<String> _cacheContent(
    String content,
    String name,
    String? identifier,
  ) {
    return widget.cacheContent?.call(content, name, identifier) ??
        FileService.cacheContent(content, name, identifier);
  }

  Future<void> _autoSave() async {
    if (_currentFile != null && _isModified) await _saveFile();
  }

  Future<void> _saveFile() async {
    if (_currentFile == null) {
      await _saveAs();
      return;
    }
    if (_currentFile!.storageType == MarkdownStorageType.webDav) {
      await _saveCloudFile();
      return;
    }
    setState(() => _isSaving = true);

    final contentToSave = _textController.text;
    final writePath = _getWritablePath();
    final success = await FileService.saveFile(
      writePath,
      contentToSave,
      contentUri: _contentUri,
    );

    if (success) {
      final name = _currentFile!.name;
      final id = _contentUri ?? _currentFile!.path;
      final contentPath = await FileService.cacheContent(
        contentToSave,
        name,
        id,
      );
      final hasPendingChanges = contentChangedSinceSave(
        contentToSave,
        _textController.text,
      );
      final updatedFile = _currentFile!.copyWith(
        content: contentToSave,
        contentPath: contentPath,
        lastModified: DateTime.now(),
        size: contentToSave.length,
      );
      if (!mounted) return;
      setState(() {
        _currentFile = updatedFile;
        _isModified = hasPendingChanges;
      });
      await HistoryService.addToHistory(updatedFile);
      if (hasPendingChanges && mounted) _scheduleAutoSave();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已保存：${_currentFile!.name}')),
        );
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('保存失败，请检查文件权限')),
      );
    }
    if (mounted) setState(() => _isSaving = false);
  }

  Future<void> _saveCloudFile({bool forceRemoteOverwrite = false}) async {
    final file = _currentFile;
    final remotePath = file?.remotePath;
    final config = widget.settingsListenable?.value.webDav;
    if (file == null ||
        remotePath == null ||
        config == null ||
        !config.isComplete) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('WebDAV 配置不可用，无法保存云端文件')),
        );
      }
      return;
    }

    if (mounted) setState(() => _isSaving = true);
    final contentToSave = _textController.text;
    try {
      final service =
          widget.webDavServiceFactory?.call(config) ?? WebDavService(config);
      if (!forceRemoteOverwrite && _hasRemoteSnapshot) {
        final metadata = await service.getMetadata(remotePath);
        final changed = metadata == null ||
            remoteSnapshotChanged(
              baselineModified: _remoteModified,
              baselineSize: _remoteSize,
              remoteModified: metadata.modified,
              remoteSize: metadata.size,
            );
        if (changed) {
          await _resolveRemoteConflict(service, metadata);
          return;
        }
      }

      final bytes = utf8.encode(contentToSave);
      await service.upload(remotePath, bytes);
      WebDavEntry? metadata;
      try {
        metadata = await service.getMetadata(remotePath);
      } catch (error, stackTrace) {
        debugPrint('读取保存后的云端文件信息失败: $error\n$stackTrace');
      }
      final snapshotModified =
          metadata?.modified ?? file.remoteModified ?? DateTime.now();
      final snapshotSize = metadata?.size ?? file.remoteSize ?? bytes.length;
      final contentPath = await FileService.cacheContent(
        contentToSave,
        file.name,
        'webdav:$remotePath',
      );
      final hasPendingChanges = contentChangedSinceSave(
        contentToSave,
        _textController.text,
      );
      final updatedFile = file
          .copyWith(
            content: contentToSave,
            contentPath: contentPath,
            lastModified: DateTime.now(),
            size: contentToSave.length,
          )
          .withRemoteSnapshot(
            modified: snapshotModified,
            size: snapshotSize,
          );
      if (!mounted) return;
      _remoteModified = snapshotModified;
      _remoteSize = snapshotSize;
      _remoteConflict = false;
      setState(() {
        _currentFile = updatedFile;
        _isModified = hasPendingChanges;
      });
      await HistoryService.addToHistory(updatedFile);
      if (hasPendingChanges && mounted) _scheduleAutoSave();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已保存到云端：${file.name}')),
        );
      }
    } catch (error, stackTrace) {
      debugPrint('保存云端 Markdown 文件失败: $error\n$stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('云端保存失败，请检查网络和配置')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _getWritablePath() {
    if (_currentFile != null) {
      final p = _currentFile!.path;
      if (p.isNotEmpty && !p.startsWith('content://')) return p;
    }
    if (_cachePath != null && _cachePath!.isNotEmpty) return _cachePath!;
    return _currentFile?.path ?? '';
  }

  Future<void> _saveAs() async {
    final settings = widget.settingsListenable?.value;
    if (settings?.webDav.isComplete == true) {
      final choice = await showStorageChoiceDialog(context);
      if (choice == null) return;
      if (choice == FileStorageChoice.webDav) {
        await _saveAsCloud();
        return;
      }
    }

    final defaultName = _currentFile?.name ?? '未命名.md';
    final result = await FileService.getSavePath(
      defaultName: defaultName,
      content: _textController.text,
    );

    if (result != null) {
      final content = _textController.text;
      final id = result.contentUri ?? result.displayPath;
      final contentPath =
          await FileService.cacheContent(content, result.name, id);
      final newFile = MarkdownFile(
        path: result.displayPath,
        contentUri: result.contentUri,
        contentPath: contentPath,
        name: result.name,
        content: content,
        lastModified: DateTime.now(),
        size: content.length,
      );
      setState(() {
        _currentFile = newFile;
        _contentUri = result.contentUri;
        _cachePath = result.path;
        _isModified = false;
      });
      await HistoryService.addToHistory(newFile);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已保存：${result.name}')),
        );
      }
    }
  }

  Future<void> _saveAsCloud() async {
    final config = widget.settingsListenable?.value.webDav;
    if (config == null || !config.isComplete) return;
    try {
      final service =
          widget.webDavServiceFactory?.call(config) ?? WebDavService(config);
      final currentPath = _currentFile?.remotePath;
      final selectedPath = await Navigator.of(context).push<String>(
        MaterialPageRoute(
          builder: (context) => WebDavFilePickerPage(
            service: service,
            saveMode: true,
            initialDirectory:
                currentPath == null ? null : _parentRemotePath(currentPath),
            initialFileName: _currentFile?.name ?? '未命名.md',
          ),
        ),
      );
      if (selectedPath == null) return;

      final content = _textController.text;
      await service.upload(selectedPath, utf8.encode(content));
      final name = _remoteName(selectedPath);
      final contentPath = await FileService.cacheContent(
        content,
        name,
        'webdav:$selectedPath',
      );
      final file = MarkdownFile(
        path: selectedPath,
        remotePath: selectedPath,
        storageType: MarkdownStorageType.webDav,
        contentPath: contentPath,
        name: name,
        content: content,
        lastModified: DateTime.now(),
        size: content.length,
      );
      if (!mounted) return;
      setState(() {
        _currentFile = file;
        _contentUri = null;
        _cachePath = null;
        _isModified = false;
      });
      await HistoryService.addToHistory(file);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已另存到云端：$name')),
        );
      }
    } catch (error, stackTrace) {
      debugPrint('云端另存为失败: $error\n$stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('云端另存为失败，请检查网络和配置')),
        );
      }
    }
  }

  String _parentRemotePath(String path) {
    final clean =
        path.endsWith('/') ? path.substring(0, path.length - 1) : path;
    final slash = clean.lastIndexOf('/');
    return slash <= 0 ? '/' : clean.substring(0, slash);
  }

  String _remoteName(String path) {
    final clean =
        path.endsWith('/') ? path.substring(0, path.length - 1) : path;
    return clean.split('/').last;
  }

  Future<void> _exportPdf() async {
    if (_isExportingPdf) return;
    setState(() => _isExportingPdf = true);

    try {
      final source = _textController.text;
      final title = (_currentFile?.name ?? '未命名')
          .replaceAll(RegExp(r'\.md$|\.markdown$', caseSensitive: false), '');
      final sourceDirectory = _currentFile != null &&
              _currentFile!.path.isNotEmpty &&
              !_currentFile!.path.startsWith('content://')
          ? File(_currentFile!.path).parent.path
          : null;

      final result = await PdfExportService.generate(
        markdown: source,
        options: PdfExportOptions(title: title),
        sourceDirectory: sourceDirectory,
      );

      final saveResult = await FileService.saveBytesAs(
        defaultName: title,
        bytes: result.bytes,
        mimeType: 'application/pdf',
      );

      if (!mounted) return;
      if (saveResult.status == FileSaveStatus.cancelled) {
        return;
      }
      if (saveResult.isSuccess) {
        final warningText =
            result.warnings.isEmpty ? 'PDF 已导出' : 'PDF 已导出，部分内容已降级处理';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(warningText)),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(saveResult.message ?? 'PDF 导出失败，请稍后重试'),
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF 导出失败：$error')),
      );
    } finally {
      if (mounted) setState(() => _isExportingPdf = false);
    }
  }

  void _insertAtCursor(String before, String middle, String after) {
    final text = _textController.text;
    final sel = _textController.selection;
    final start =
        (sel.start >= 0 && sel.start <= text.length) ? sel.start : text.length;
    final end = (sel.end >= 0 && sel.end <= text.length && sel.end >= start)
        ? sel.end
        : start;
    final selected = text.substring(start, end);
    final insertion =
        before + (selected.isNotEmpty ? selected : middle) + after;
    final newText = text.replaceRange(start, end, insertion);
    _textController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + insertion.length),
    );
  }

  Future<void> _insertImage() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('插入图片'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '请输入图片地址'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('确认'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result != null && result.isNotEmpty) {
      _insertAtCursor('![', 'image', ']($result)');
    }
  }

  Future<void> _insertLink() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('插入链接'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '请输入链接地址'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('确认'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result != null && result.isNotEmpty) {
      _insertAtCursor('[', '链接', ']($result)');
    }
  }

  Future<void> _onPopInvokedWithResult(bool didPop, dynamic result) async {
    if (didPop) return;
    if (!_isModified) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('保存更改？'),
        content: const Text('您有未保存的更改。离开前要保存吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('放弃'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (shouldSave == true) {
      await _saveFile();
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _remoteSyncTimer?.cancel();
    widget.settingsListenable?.removeListener(_onSettingsChanged);
    _textController.dispose();
    _tabController.dispose();
    _editorScrollController.dispose();
    _previewScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 600;
    return PopScope(
      canPop: !_isModified,
      onPopInvokedWithResult: _onPopInvokedWithResult,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_currentFile?.name ?? '新建文档'),
          actions: [
            if (_isSaving)
              const Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            if (_isModified && !_isSaving)
              IconButton(
                icon: const Icon(Icons.save),
                tooltip: '保存',
                onPressed: _saveFile,
              ),
            IconButton(
              icon: const Icon(Icons.save_as),
              tooltip: '另存为',
              onPressed: _saveAs,
            ),
            IconButton(
              icon: const Icon(Icons.share),
              tooltip: '分享',
              onPressed: () {
                if (_currentFile != null) {
                  FileService.shareContent(
                      _textController.text, _currentFile!.name);
                }
              },
            ),
          ],
        ),
        body: isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Column(
      children: [
        EditorToolbar(
          controller: _textController,
          onInsertImage: _insertImage,
          onInsertLink: _insertLink,
        ),
        Expanded(
          child: Row(
            children: [
              Expanded(child: _buildEditor()),
              Container(width: 1, color: Theme.of(context).dividerColor),
              Expanded(
                child: MarkdownPreview(
                  data: _textController.text,
                  scrollController: _previewScrollController,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.edit), text: '编辑'),
            Tab(icon: Icon(Icons.preview), text: '预览'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              Column(
                children: [
                  EditorToolbar(
                    controller: _textController,
                    onInsertImage: _insertImage,
                    onInsertLink: _insertLink,
                  ),
                  Expanded(child: _buildEditor()),
                ],
              ),
              MarkdownPreview(
                data: _textController.text,
                scrollController: _previewScrollController,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEditor() {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _textController,
        scrollController: _editorScrollController,
        maxLines: null,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
        style: Theme.of(context)
            .textTheme
            .bodyLarge
            ?.copyWith(fontFamily: 'monospace', height: 1.5),
        decoration: const InputDecoration(
          border: InputBorder.none,
          hintText: '开始编写 Markdown...',
        ),
        keyboardType: TextInputType.multiline,
      ),
    );
  }
}
