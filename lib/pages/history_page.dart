import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/app_settings.dart';
import '../models/markdown_file.dart';
import '../models/webdav_entry.dart';
import '../services/file_service.dart';
import '../services/history_service.dart';
import '../services/pdf_export_service.dart';
import '../export/export_docx.dart';
import '../export/export_html.dart';
import '../services/webdav_service.dart';
import 'editor_page.dart';

class HistoryPage extends StatefulWidget {
  final ValueListenable<AppSettings> settingsListenable;
  final WebDavService Function(WebDavConfig config) webDavServiceFactory;

  const HistoryPage({
    super.key,
    required this.settingsListenable,
    required this.webDavServiceFactory,
  });

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<MarkdownFile> _history = [];
  bool _isLoading = true;
  bool _isExportingPdf = false;
  bool _isExportingDocx = false;
  bool _isExportingHtml = false;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
    });

    final history = await HistoryService.getHistory();
    if (!mounted) return;

    setState(() {
      _history = history;
      _isLoading = false;
    });
  }

  void _openFile(MarkdownFile file) {
    if (file.storageType == MarkdownStorageType.webDav) {
      _openCloudFile(file);
      return;
    }
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
        .then((_) => _loadHistory());
  }

  Future<void> _openCloudFile(MarkdownFile file) async {
    final config = widget.settingsListenable.value.webDav;
    if (!config.isComplete || file.remotePath == null) {
      _showExportMessage('WebDAV 配置不可用，无法打开云端历史文件');
      return;
    }
    try {
      final service = widget.webDavServiceFactory(config);
      final content = utf8.decode(await service.download(file.remotePath!));
      WebDavEntry? metadata;
      try {
        metadata = await service.getMetadata(file.remotePath!);
      } catch (error, stackTrace) {
        debugPrint('读取历史云端文件元数据失败: $error\n$stackTrace');
      }
      final contentPath = await FileService.cacheContent(
        content,
        file.name,
        'webdav:${file.remotePath}',
      );
      final updatedFile = file.copyWith(
        content: content,
        contentPath: contentPath,
        lastModified: DateTime.now(),
        size: content.length,
        remoteModified: metadata?.modified,
        remoteSize: metadata?.size,
      );
      if (!mounted) return;
      Navigator.of(context)
          .push(
            MaterialPageRoute(
              builder: (context) => EditorPage(
                file: updatedFile,
                settingsListenable: widget.settingsListenable,
                webDavServiceFactory: widget.webDavServiceFactory,
              ),
            ),
          )
          .then((_) => _loadHistory());
    } catch (error, stackTrace) {
      debugPrint('打开历史云端文件失败: $error\n$stackTrace');
      if (mounted) _showExportMessage('打开云端历史文件失败，请检查网络和配置');
    }
  }

  Future<void> _exportPdf(MarkdownFile file) async {
    if (_isExportingPdf) return;
    setState(() => _isExportingPdf = true);
    _showExportProgress('正在准备 PDF 导出...');

    try {
      final content = await _loadMarkdownContent(file);
      if (!mounted) return;
      if (content == null || content.isEmpty) {
        _showExportMessage('无法读取文件内容，无法导出 PDF');
        return;
      }

      _showExportProgress('正在生成 PDF，请稍候...');
      final title = file.name.replaceAll(
        RegExp(r'\.md$|\.markdown$', caseSensitive: false),
        '',
      );
      final result = await PdfExportService.generate(
        markdown: content,
        options: PdfExportOptions(title: title),
        sourceDirectory: _sourceDirectoryOf(file),
      );
      if (!mounted) return;

      _showExportProgress('PDF 已生成，正在打开保存位置...');
      final saveResult = await FileService.saveBytesAs(
        defaultName: title,
        bytes: result.bytes,
        mimeType: 'application/pdf',
      );
      if (!mounted) return;
      if (saveResult.status == FileSaveStatus.cancelled) return;
      if (saveResult.isSuccess) {
        _showExportMessage(
          result.warnings.isEmpty ? 'PDF 已成功导出' : 'PDF 已导出，部分内容已降级处理',
        );
      } else {
        _showExportMessage(saveResult.message ?? 'PDF 导出失败，请稍后重试');
      }
    } catch (error) {
      if (mounted) _showExportMessage('PDF 导出失败，请稍后重试');
    } finally {
      if (mounted) setState(() => _isExportingPdf = false);
    }
  }

  Future<void> _exportDocx(MarkdownFile file) async {
    if (_isExportingDocx) return;
    setState(() => _isExportingDocx = true);
    _showExportProgress('正在准备 DOCX 导出...');

    try {
      final content = await _loadMarkdownContent(file);
      if (!mounted) return;
      if (content == null || content.isEmpty) {
        _showExportMessage('无法读取文件内容，无法导出 DOCX');
        return;
      }

      _showExportProgress('正在生成 DOCX，请稍候...');
      final title = file.name.replaceAll(
        RegExp(r'\.md$|\.markdown$', caseSensitive: false),
        '',
      );
      final result = await MarkdownDocxExporter.generate(
        markdown: content,
        title: title,
      );
      if (!mounted) return;

      _showExportProgress('DOCX 已生成，正在打开保存位置...');
      final saveResult = await FileService.saveBytesAs(
        defaultName: title,
        bytes: result.bytes,
        mimeType:
            'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      );
      if (!mounted) return;
      if (saveResult.status == FileSaveStatus.cancelled) return;
      if (saveResult.isSuccess) {
        _showExportMessage(
            result.warnings.isEmpty ? 'DOCX 已成功导出' : 'DOCX 已导出，部分内容已降级处理');
      } else {
        _showExportMessage(saveResult.message ?? 'DOCX 导出失败，请稍后重试');
      }
    } catch (error) {
      if (mounted) _showExportMessage('DOCX 导出失败，请稍后重试');
    } finally {
      if (mounted) setState(() => _isExportingDocx = false);
    }
  }

  Future<void> _exportHtml(MarkdownFile file) async {
    if (_isExportingHtml) return;
    setState(() => _isExportingHtml = true);
    _showExportProgress('正在准备 HTML 导出...');

    try {
      final content = await _loadMarkdownContent(file);
      if (!mounted) return;
      if (content == null || content.isEmpty) {
        _showExportMessage('无法读取文件内容，无法导出 HTML');
        return;
      }

      _showExportProgress('正在生成 HTML，请稍候...');
      final title = file.name.replaceAll(
        RegExp(r'\.md$|\.markdown$', caseSensitive: false),
        '',
      );
      final html = markdownToHtml(content, title: title);
      if (!mounted) return;

      _showExportProgress('HTML 已生成，正在打开保存位置...');
      final saveResult = await FileService.saveBytesAs(
        defaultName: title,
        bytes: Uint8List.fromList(utf8.encode(html)),
        mimeType: 'text/html',
      );
      if (!mounted) return;
      if (saveResult.status == FileSaveStatus.cancelled) return;
      if (saveResult.isSuccess) {
        _showExportMessage('HTML 已成功导出');
      } else {
        _showExportMessage(saveResult.message ?? 'HTML 导出失败，请稍后重试');
      }
    } catch (error) {
      if (mounted) _showExportMessage('HTML 导出失败，请稍后重试');
    } finally {
      if (mounted) setState(() => _isExportingHtml = false);
    }
  }

  void _showExportProgress(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(message)),
            ],
          ),
          duration: const Duration(minutes: 1),
        ),
      );
  }

  void _showExportMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String? _sourceDirectoryOf(MarkdownFile file) {
    if (file.path.isNotEmpty && !file.path.startsWith('content://')) {
      return file.path.contains('/') || file.path.contains('\\')
          ? file.path.substring(0, file.path.lastIndexOf(RegExp(r'[/\\]')))
          : null;
    }
    return null;
  }

  Future<String?> _loadMarkdownContent(MarkdownFile file) async {
    if (file.contentPath != null && file.contentPath!.isNotEmpty) {
      final cached = await FileService.openFile(file.contentPath!);
      if (cached != null) return cached.content;
    }

    if (file.path.isNotEmpty && !file.path.startsWith('content://')) {
      final direct = await FileService.openFile(file.path);
      if (direct != null) return direct.content;
    }

    if (file.contentUri != null && file.contentUri!.isNotEmpty) {
      return await FileService.readContentViaUri(file.contentUri!);
    }

    return null;
  }

  void _showFileDetails(MarkdownFile file) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('文件详情'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('名称', file.name),
            const SizedBox(height: 8),
            _buildDetailRow('路径', file.path),
            const SizedBox(height: 8),
            _buildDetailRow('大小', FileService.formatFileSize(file.size)),
            const SizedBox(height: 8),
            _buildDetailRow(
              '最后修改',
              DateFormat('yyyy-MM-dd HH:mm:ss').format(file.lastModified),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: Text(value),
        ),
      ],
    );
  }

  Future<void> _deleteHistory(MarkdownFile file) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除历史'),
        content: Text('从历史中删除"${file.name}"？原文件不会被删除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await HistoryService.removeFile(file);
      if (!mounted) return;
      await _loadHistory();
    }
  }

  Future<void> _deleteOriginalFile(MarkdownFile file) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除原文件'),
        content: Text(
          '确定要删除原文件“${file.name}”吗？\n\n'
          '文件将从设备或存储提供程序中永久删除，此操作无法撤销。'
          '删除成功后，该记录也会从历史中移除。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除原文件'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final result = await FileService.deleteOriginalFile(file);
    if (!mounted) return;

    if (result.isSuccess) {
      final cacheDeleted = await FileService.deleteCachedContent(file);
      await HistoryService.removeFile(file);
      if (!mounted) return;
      await _loadHistory();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(cacheDeleted ? '原文件已删除' : '原文件已删除，缓存清理失败'),
        ),
      );
      return;
    }

    final message = switch (result.status) {
      FileDeletionStatus.notFound => '未找到原文件。历史记录未删除，您仍可选择“从历史中删除”。',
      FileDeletionStatus.permissionDenied => '没有删除原文件的权限。历史记录未删除。',
      FileDeletionStatus.unsupported => '当前存储位置不支持删除此文件。历史记录未删除。',
      FileDeletionStatus.invalidTarget => '无法确定原文件位置。历史记录未删除。',
      _ => '删除原文件失败，请稍后重试。历史记录未删除。',
    };
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _showContextMenu(MarkdownFile file) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('查看文件详情'),
              onTap: () {
                Navigator.of(context).pop();
                _showFileDetails(file);
              },
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('分享文件'),
              onTap: () {
                Navigator.of(context).pop();
                FileService.shareFile(file.path);
              },
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf),
              title: const Text('导出为 PDF'),
              onTap: () {
                if (_isExportingPdf) return;
                Navigator.of(context).pop();
                _exportPdf(file);
              },
            ),
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: const Text('导出为 DOCX'),
              onTap: () {
                if (_isExportingDocx) return;
                Navigator.of(context).pop();
                _exportDocx(file);
              },
            ),
            ListTile(
              leading: const Icon(Icons.language),
              title: const Text('导出为 HTML'),
              onTap: () {
                if (_isExportingHtml) return;
                Navigator.of(context).pop();
                _exportHtml(file);
              },
            ),
            if (file.storageType == MarkdownStorageType.local)
              ListTile(
                leading: const Icon(Icons.folder),
                title: const Text('打开文件所在位置'),
                onTap: () {
                  Navigator.of(context).pop();
                  FileService.openFileLocation(file.path,
                      contentUri: file.contentUri);
                },
              ),
            const Divider(),
            ListTile(
              leading: Icon(
                Icons.delete_outline,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                '从历史中删除',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              onTap: () {
                Navigator.of(context).pop();
                _deleteHistory(file);
              },
            ),
            if (file.storageType == MarkdownStorageType.local)
              ListTile(
                leading: Icon(
                  Icons.delete_forever,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(
                  '删除原文件',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  _deleteOriginalFile(file);
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('历史'),
        actions: [
          if (_history.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              tooltip: '清空全部',
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('清空全部历史'),
                    content: const Text('确定要清空所有历史吗？'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('取消'),
                      ),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.error,
                        ),
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('清空全部'),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  await HistoryService.clearHistory();
                  if (mounted) await _loadHistory();
                }
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _history.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  itemCount: _history.length,
                  itemBuilder: (context, index) {
                    final file = _history[index];
                    return _buildHistoryItem(file);
                  },
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            '暂无历史',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            '最近编辑的文件将显示在此处',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryItem(MarkdownFile file) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: () => _openFile(file),
        onLongPress: () => _showContextMenu(file),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.description,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      file.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${FileService.formatFileSize(file.size)} • ${_formatDate(file.lastModified)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.color
                                ?.withValues(alpha: 0.7),
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      file.path,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.color
                                ?.withValues(alpha: 0.5),
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.more_vert),
                onPressed: () => _showContextMenu(file),
              ),
            ],
          ),
        ),
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
      return DateFormat('M月d日 yyyy').format(date);
    }
  }
}
