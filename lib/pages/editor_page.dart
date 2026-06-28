import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/markdown_file.dart';
import '../services/file_service.dart';
import '../services/history_service.dart';
import '../widgets/editor_toolbar.dart';
import '../widgets/markdown_preview.dart';

class EditorPage extends StatefulWidget {
  final MarkdownFile? file;
  final String? initialFilePath;

  const EditorPage({
    super.key,
    this.file,
    this.initialFilePath,
  });

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> with SingleTickerProviderStateMixin {
  late TextEditingController _textController;
  late TabController _tabController;
  late ScrollController _editorScrollController;
  late ScrollController _previewScrollController;

  MarkdownFile? _currentFile;
  bool _isModified = false;
  bool _isDesktop = false;
  Timer? _autoSaveTimer;
  bool _isSaving = false;

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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _isDesktop = MediaQuery.of(context).size.width > 600;
  }

  Future<void> _loadInitialFile() async {
    if (widget.file != null) {
      _currentFile = widget.file;
      _textController.text = widget.file!.content;
      _isModified = false;
    } else if (widget.initialFilePath != null) {
      final file = await FileService.openFile(widget.initialFilePath!);
      if (file != null) {
        setState(() {
          _currentFile = file;
          _textController.text = file.content;
        });
        _isModified = false;
        await HistoryService.addToHistory(file);
      }
    }
  }

  void _setupAutoSave() {
    _textController.addListener(() {
      if (!_isModified) {
        setState(() {
          _isModified = true;
        });
      }

      // 重置自动保存计时器
      _autoSaveTimer?.cancel();
      _autoSaveTimer = Timer(const Duration(seconds: 30), () {
        _autoSave();
      });
    });
  }

  Future<void> _autoSave() async {
    if (_currentFile != null && _isModified) {
      await _saveFile();
    }
  }

  Future<void> _saveFile() async {
    if (_currentFile == null) {
      await _saveAs();
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final success = await FileService.saveFile(
      _currentFile!.path,
      _textController.text,
    );

    if (success) {
      final savedPath = _currentFile!.path;
      final updatedFile = _currentFile!.copyWith(
        content: _textController.text,
        lastModified: DateTime.now(),
        size: _textController.text.length,
      );

      setState(() {
        _currentFile = updatedFile;
        _isModified = false;
      });

      await HistoryService.addToHistory(updatedFile);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已保存：$savedPath')),
        );
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('保存失败，请检查文件权限')),
      );
    }

    setState(() {
      _isSaving = false;
    });
  }

  Future<void> _saveAs() async {
    final defaultName = _currentFile?.name ?? '未命名.md';
    final path = await FileService.getSavePath(defaultName: defaultName);

    if (path != null) {
      final success = await FileService.saveFile(path, _textController.text);
      if (success) {
        final newFile = MarkdownFile(
          path: path,
          name: path.split(RegExp(r'[/\\]')).last,
          content: _textController.text,
          lastModified: DateTime.now(),
          size: _textController.text.length,
        );

        setState(() {
          _currentFile = newFile;
          _isModified = false;
        });

        await HistoryService.addToHistory(newFile);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('文件保存成功')),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('保存失败，请检查文件权限')),
        );
      }
    }
  }

  Future<void> _insertImage() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      final imagePath = image.path;
      final imageMarkdown = '![image]($imagePath)';

      final text = _textController.text;
      final selection = _textController.selection;

      final newText = text.replaceRange(
        selection.start,
        selection.end,
        imageMarkdown,
      );

      _textController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(
          offset: selection.start + imageMarkdown.length,
        ),
      );
    }
  }

  Future<void> _onPopInvokedWithResult(bool didPop, dynamic result) async {
    if (didPop) return;
    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('保存更改？'),
        content: const Text('您有未保存的更改。离开前要保存吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('放弃'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('保存'),
          ),
        ],
      ),
    );

    if (shouldSave == true) {
      await _saveFile();
      if (mounted) {
        Navigator.of(context).pop();
      }
    } else if (shouldSave == false) {
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
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
                  FileService.shareFile(_currentFile!.path);
                }
              },
            ),
          ],
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isDesktop) {
      return _buildDesktopLayout();
    } else {
      return _buildMobileLayout();
    }
  }

  Widget _buildDesktopLayout() {
    return Column(
      children: [
        EditorToolbar(
          controller: _textController,
          onInsertImage: (_) => _insertImage(),
          onInsertLink: (_) {},
        ),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: _buildEditor(),
              ),
              Container(
                width: 1,
                color: Theme.of(context).dividerColor,
              ),
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
                    onInsertImage: (_) => _insertImage(),
                    onInsertLink: (_) {},
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
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontFamily: 'monospace',
              height: 1.5,
            ),
        decoration: const InputDecoration(
          border: InputBorder.none,
          hintText: '开始编写 Markdown...',
        ),
        keyboardType: TextInputType.multiline,
      ),
    );
  }
}
