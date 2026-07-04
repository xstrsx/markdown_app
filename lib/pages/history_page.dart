import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/markdown_file.dart';
import '../services/file_service.dart';
import '../services/history_service.dart';
import 'editor_page.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<MarkdownFile> _history = [];
  bool _isLoading = true;

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

    setState(() {
      _history = history;
      _isLoading = false;
    });
  }

  void _openFile(MarkdownFile file) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => EditorPage(file: file),
      ),
    ).then((_) => _loadHistory());
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
        content: Text('从历史中删除"${file.name}"？'),
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
      await HistoryService.removeFromHistory(file.path);
      _loadHistory();
    }
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
                  _loadHistory();
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
                            color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      file.path,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.5),
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
