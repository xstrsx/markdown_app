import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/app_settings.dart';
import '../models/markdown_file.dart';
import '../services/file_service.dart';
import '../services/history_service.dart';
import '../services/webdav_service.dart';
import 'webdav_file_picker_page.dart';
import '../widgets/storage_choice_dialog.dart';
import 'editor_page.dart';

class HomePage extends StatefulWidget {
  final ValueListenable<AppSettings> settingsListenable;
  final WebDavService Function(WebDavConfig config) webDavServiceFactory;

  const HomePage({
    super.key,
    required this.settingsListenable,
    required this.webDavServiceFactory,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<MarkdownFile> _recentFiles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecentFiles();
  }

  Future<void> _loadRecentFiles() async {
    setState(() {
      _isLoading = true;
    });

    final files = await HistoryService.getRecentFiles(limit: 3);
    if (!mounted) return;

    setState(() {
      _recentFiles = files;
      _isLoading = false;
    });
  }

  Future<void> _createNewFile() async {
    final storage = await _chooseStorage();
    if (!mounted) return;
    if (storage == null && widget.settingsListenable.value.webDav.isComplete) {
      return;
    }
    if (storage == FileStorageChoice.webDav) {
      await _createCloudFile();
      return;
    }

    final fileNameController = TextEditingController(text: '未命名.md');

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('新建 Markdown 文件'),
        content: TextField(
          controller: fileNameController,
          decoration: const InputDecoration(
            labelText: '文件名',
            hintText: '示例.md',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(fileNameController.text),
            child: const Text('创建'),
          ),
        ],
      ),
    );

    fileNameController.dispose();

    if (result != null && result.isNotEmpty) {
      final fileName = result.endsWith('.md') ? result : '$result.md';
      final filePath = await FileService.createNewFile(fileName);

      if (mounted) {
        Navigator.of(context)
            .push(
              MaterialPageRoute(
                builder: (context) => EditorPage(
                  initialFilePath: filePath,
                  settingsListenable: widget.settingsListenable,
                  webDavServiceFactory: widget.webDavServiceFactory,
                ),
              ),
            )
            .then((_) => _loadRecentFiles());
      }
    }
  }

  Future<void> _openFile() async {
    final storage = await _chooseStorage();
    if (storage == null && widget.settingsListenable.value.webDav.isComplete) {
      return;
    }
    if (storage == FileStorageChoice.webDav) {
      await _openCloudFile();
      return;
    }

    final result = await FileService.pickMarkdownFile();

    if (result != null && mounted) {
      Navigator.of(context)
          .push(
            MaterialPageRoute(
              builder: (context) => EditorPage(
                initialFilePath: result.path,
                initialDisplayPath: result.displayPath,
                initialContentUri: result.contentUri,
                initialName: result.name,
                settingsListenable: widget.settingsListenable,
                webDavServiceFactory: widget.webDavServiceFactory,
              ),
            ),
          )
          .then((_) => _loadRecentFiles());
    }
  }

  void _openRecentFile(MarkdownFile file) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (context) => EditorPage(
              file: file,
              settingsListenable: widget.settingsListenable,
              webDavServiceFactory: widget.webDavServiceFactory,
            ),
          ),
        )
        .then((_) => _loadRecentFiles());
  }

  Future<FileStorageChoice?> _chooseStorage() {
    if (!widget.settingsListenable.value.webDav.isComplete) {
      return Future.value(FileStorageChoice.local);
    }
    return showStorageChoiceDialog(context);
  }

  WebDavService _webDavService() {
    return widget.webDavServiceFactory(
      widget.settingsListenable.value.webDav,
    );
  }

  Future<void> _createCloudFile() async {
    final path = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (context) => WebDavFilePickerPage(
          service: _webDavService(),
          saveMode: true,
        ),
      ),
    );
    if (path == null || !mounted) return;
    final file = MarkdownFile(
      path: path,
      remotePath: path,
      storageType: MarkdownStorageType.webDav,
      name: _fileName(path),
      content: '',
      lastModified: DateTime.now(),
      size: 0,
    );
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (context) => EditorPage(
              file: file,
              settingsListenable: widget.settingsListenable,
              webDavServiceFactory: widget.webDavServiceFactory,
            ),
          ),
        )
        .then((_) => _loadRecentFiles());
  }

  Future<void> _openCloudFile() async {
    try {
      final service = _webDavService();
      final path = await Navigator.of(context).push<String>(
        MaterialPageRoute(
          builder: (context) => WebDavFilePickerPage(
            service: service,
            saveMode: false,
          ),
        ),
      );
      if (path == null || !mounted) return;
      final content = utf8.decode(await service.download(path));
      final contentPath = await FileService.cacheContent(
        content,
        _fileName(path),
        'webdav:$path',
      );
      final file = MarkdownFile(
        path: path,
        remotePath: path,
        storageType: MarkdownStorageType.webDav,
        contentPath: contentPath,
        name: _fileName(path),
        content: content,
        lastModified: DateTime.now(),
        size: content.length,
      );
      if (!mounted) return;
      Navigator.of(context)
          .push(
            MaterialPageRoute(
              builder: (context) => EditorPage(
                file: file,
                settingsListenable: widget.settingsListenable,
                webDavServiceFactory: widget.webDavServiceFactory,
              ),
            ),
          )
          .then((_) => _loadRecentFiles());
    } catch (error, stackTrace) {
      debugPrint('打开云端 Markdown 文件失败: $error\n$stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('打开云端文件失败，请检查网络和配置')),
        );
      }
    }
  }

  String _fileName(String path) {
    final clean =
        path.endsWith('/') ? path.substring(0, path.length - 1) : path;
    return clean.split('/').last;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.edit_note,
                  size: 80,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'MD 编辑器',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  '创建和编辑精美的 Markdown 文档',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context)
                            .textTheme
                            .bodyLarge
                            ?.color
                            ?.withValues(alpha: 0.7),
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                FilledButton.icon(
                  onPressed: _createNewFile,
                  icon: const Icon(Icons.add),
                  label: const Text('新建 Markdown 文件'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _openFile,
                  icon: const Icon(Icons.folder_open),
                  label: const Text('打开本地 Markdown 文件'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
                const SizedBox(height: 32),
                if (_isLoading)
                  const Center(child: CircularProgressIndicator())
                else if (_recentFiles.isNotEmpty) ...[
                  Text(
                    '最近文件',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),
                  ..._recentFiles.map((file) => _buildRecentFileCard(file)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecentFileCard(MarkdownFile file) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.description),
        title: Text(file.name),
        subtitle: Text(
          '${FileService.formatFileSize(file.size)} • ${_formatDate(file.lastModified)}',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _openRecentFile(file),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}分钟前';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}小时前';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}天前';
    } else {
      return '${date.year}年${date.month}月${date.day}日';
    }
  }
}
