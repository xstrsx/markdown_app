import 'package:flutter/material.dart';

import '../models/webdav_entry.dart';
import '../services/webdav_service.dart';

class WebDavFilePickerPage extends StatefulWidget {
  final WebDavService service;
  final bool saveMode;
  final String? initialDirectory;

  const WebDavFilePickerPage({
    super.key,
    required this.service,
    required this.saveMode,
    this.initialDirectory,
  });

  @override
  State<WebDavFilePickerPage> createState() => _WebDavFilePickerPageState();
}

class _WebDavFilePickerPageState extends State<WebDavFilePickerPage> {
  late String _directory;
  late final TextEditingController _fileNameController;
  List<WebDavEntry> _entries = [];
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _directory = widget.service.normalizePath(
      widget.initialDirectory ?? widget.service.rootPath,
    );
    _fileNameController = TextEditingController(text: '未命名.md');
    _loadDirectory();
  }

  Future<void> _loadDirectory() async {
    if (mounted) setState(() => _loading = true);
    try {
      final entries = await widget.service.listDirectory(_directory);
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _error = null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _enterDirectory(WebDavEntry entry) async {
    if (!entry.isDirectory) {
      Navigator.of(context).pop(entry.path);
      return;
    }
    setState(() {
      _directory = widget.service.normalizePath(entry.path);
    });
    await _loadDirectory();
  }

  Future<void> _goUp() async {
    if (_directory == widget.service.rootPath) return;
    final lastSlash = _directory.lastIndexOf('/');
    final parent = lastSlash <= 0 ? '/' : _directory.substring(0, lastSlash);
    setState(() {
      _directory = widget.service.normalizePath(parent);
    });
    await _loadDirectory();
  }

  void _saveFile() {
    final name = _fileNameController.text.trim();
    if (name.isEmpty ||
        name.contains('/') ||
        name.contains('\\') ||
        name.contains('..')) {
      _showError('文件名不能包含路径分隔符或上级目录');
      return;
    }
    final normalizedName = name.toLowerCase().endsWith('.md') ||
            name.toLowerCase().endsWith('.markdown')
        ? name
        : '$name.md';
    Navigator.of(context).pop(
      widget.service.normalizePath('$_directory/$normalizedName'),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _fileNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visibleEntries = widget.saveMode
        ? _entries
        : _entries.where((entry) {
            return entry.isDirectory ||
                entry.name.toLowerCase().endsWith('.md') ||
                entry.name.toLowerCase().endsWith('.markdown');
          }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.saveMode ? '保存到云端' : '打开云端文件'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '刷新',
            onPressed: _loading ? null : _loadDirectory,
          ),
        ],
      ),
      body: Column(
        children: [
          ListTile(
            leading: IconButton(
              icon: const Icon(Icons.arrow_upward),
              tooltip: '返回上级',
              onPressed: _directory == widget.service.rootPath ? null : _goUp,
            ),
            title: Text(_directory),
          ),
          if (widget.saveMode)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _fileNameController,
                      decoration: const InputDecoration(labelText: '文件名'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _loading ? null : _saveFile,
                    child: const Text('保存到云端'),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _buildError()
                    : ListView.builder(
                        itemCount: visibleEntries.length,
                        itemBuilder: (context, index) {
                          final entry = visibleEntries[index];
                          return ListTile(
                            leading: Icon(
                              entry.isDirectory
                                  ? Icons.folder_outlined
                                  : Icons.description_outlined,
                            ),
                            title: Text(entry.name),
                            trailing: entry.isDirectory
                                ? const Icon(Icons.chevron_right)
                                : null,
                            onTap: widget.saveMode && !entry.isDirectory
                                ? null
                                : () => _enterDirectory(entry),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('读取云端目录失败'),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _loadDirectory,
            icon: const Icon(Icons.refresh),
            label: const Text('重试'),
          ),
        ],
      ),
    );
  }
}
