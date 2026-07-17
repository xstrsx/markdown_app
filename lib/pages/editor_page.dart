import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../models/markdown_file.dart';
import '../services/file_service.dart';
import '../services/history_service.dart';
import '../services/pdf_export_service.dart';
import '../widgets/editor_toolbar.dart';
import '../widgets/markdown_preview.dart';

class EditorPage extends StatefulWidget {
  final MarkdownFile? file;
  final String? initialFilePath;
  final String? initialDisplayPath;
  final String? initialContentUri;
  final String? initialName;
  final bool exportPdfOnOpen;

  const EditorPage({
    super.key,
    this.file,
    this.initialFilePath,
    this.initialDisplayPath,
    this.initialContentUri,
    this.initialName,
    this.exportPdfOnOpen = false,
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
  bool _isSaving = false;
  bool _isExportingPdf = false;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    _editorScrollController = ScrollController();
    _previewScrollController = ScrollController();
    _tabController = TabController(length: 2, vsync: this);
    _loadInitialFile();
    _setupAutoSave();
  }

  Future<void> _loadInitialFile() async {
    try {
      if (widget.file != null) {
        final file = widget.file!;
        _currentFile = file;
        _contentUri = file.contentUri;
        _cachePath = file.contentPath;

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
      _autoSaveTimer?.cancel();
      _autoSaveTimer = Timer(const Duration(seconds: 30), _autoSave);
    });
  }

  Future<void> _autoSave() async {
    if (_currentFile != null && _isModified) await _saveFile();
  }

  Future<void> _saveFile() async {
    if (_currentFile == null) {
      await _saveAs();
      return;
    }
    setState(() => _isSaving = true);

    final writePath = _getWritablePath();
    final success = await FileService.saveFile(
      writePath,
      _textController.text,
      contentUri: _contentUri,
    );

    if (success) {
      final name = _currentFile!.name;
      final content = _textController.text;
      final id = _contentUri ?? _currentFile!.path;
      final contentPath = await FileService.cacheContent(content, name, id);
      final updatedFile = _currentFile!.copyWith(
        content: content,
        contentPath: contentPath,
        lastModified: DateTime.now(),
        size: content.length,
      );
      setState(() {
        _currentFile = updatedFile;
        _isModified = false;
      });
      await HistoryService.addToHistory(updatedFile);
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

  String _getWritablePath() {
    if (_currentFile != null) {
      final p = _currentFile!.path;
      if (p.isNotEmpty && !p.startsWith('content://')) return p;
    }
    if (_cachePath != null && _cachePath!.isNotEmpty) return _cachePath!;
    return _currentFile?.path ?? '';
  }

  Future<void> _saveAs() async {
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
