import 'package:flutter/material.dart';

class EditorToolbar extends StatelessWidget {
  final TextEditingController controller;
  final Function(String) onInsertImage;
  final Function(String) onInsertLink;

  const EditorToolbar({
    super.key,
    required this.controller,
    required this.onInsertImage,
    required this.onInsertLink,
  });

  void _insertAround(String before, String after, {String placeholder = ''}) {
    final text = controller.text;
    final selection = controller.selection;
    final selectedText = selection.isValid ? selection.textInside(text) : placeholder;

    final newText = text.replaceRange(
      selection.start,
      selection.end,
      '$before$selectedText$after',
    );

    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: selection.start + before.length + selectedText.length,
      ),
    );
  }

  void _insertLine(String prefix) {
    final text = controller.text;
    final selection = controller.selection;

    // 找到当前行的起始位置
    int lineStart = selection.start;
    while (lineStart > 0 && text[lineStart - 1] != '\n') {
      lineStart--;
    }

    final newText = text.replaceRange(lineStart, lineStart, prefix);

    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: selection.start + prefix.length,
      ),
    );
  }

  void _insertBlock(String content) {
    final text = controller.text;
    final selection = controller.selection;

    final newText = text.replaceRange(
      selection.start,
      selection.end,
      content,
    );

    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: selection.start + content.length,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 1,
          ),
        ),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        children: [
          _buildToolbarButton(
            icon: Icons.title,
            tooltip: '标题 1',
            onPressed: () => _insertLine('# '),
          ),
          _buildToolbarButton(
            icon: Icons.title,
            tooltip: '标题 2',
            onPressed: () => _insertLine('## '),
            fontSize: 14,
          ),
          _buildToolbarButton(
            icon: Icons.title,
            tooltip: '标题 3',
            onPressed: () => _insertLine('### '),
            fontSize: 12,
          ),
          _buildDivider(),
          _buildToolbarButton(
            icon: Icons.format_bold,
            tooltip: '加粗',
            onPressed: () => _insertAround('**', '**', placeholder: '加粗文本'),
          ),
          _buildToolbarButton(
            icon: Icons.format_italic,
            tooltip: '斜体',
            onPressed: () => _insertAround('*', '*', placeholder: '斜体文本'),
          ),
          _buildToolbarButton(
            icon: Icons.format_strikethrough,
            tooltip: '删除线',
            onPressed: () => _insertAround('~~', '~~', placeholder: '删除线文本'),
          ),
          _buildDivider(),
          _buildToolbarButton(
            icon: Icons.format_list_bulleted,
            tooltip: '无序列表',
            onPressed: () => _insertLine('- '),
          ),
          _buildToolbarButton(
            icon: Icons.format_list_numbered,
            tooltip: '有序列表',
            onPressed: () => _insertLine('1. '),
          ),
          _buildToolbarButton(
            icon: Icons.check_box,
            tooltip: '任务列表',
            onPressed: () => _insertLine('- [ ] '),
          ),
          _buildDivider(),
          _buildToolbarButton(
            icon: Icons.format_quote,
            tooltip: '引用',
            onPressed: () => _insertLine('> '),
          ),
          _buildToolbarButton(
            icon: Icons.code,
            tooltip: '行内代码',
            onPressed: () => _insertAround('`', '`', placeholder: '代码'),
          ),
          _buildToolbarButton(
            icon: Icons.code_off,
            tooltip: '代码块',
            onPressed: () => _insertBlock('```\n代码块\n```\n'),
          ),
          _buildDivider(),
          _buildToolbarButton(
            icon: Icons.link,
            tooltip: '链接',
            onPressed: () => _insertAround('[', '](url)', placeholder: '链接文字'),
          ),
          _buildToolbarButton(
            icon: Icons.image,
            tooltip: '图片',
            onPressed: () => _insertBlock('![替代文本](图片链接)'),
          ),
          _buildDivider(),
          _buildToolbarButton(
            icon: Icons.table_chart,
            tooltip: '表格',
            onPressed: () => _insertBlock(
              '\n| 表头 1 | 表头 2 | 表头 3 |\n| --- | --- | --- |\n| 单元格 1 | 单元格 2 | 单元格 3 |\n',
            ),
          ),
          _buildToolbarButton(
            icon: Icons.horizontal_rule,
            tooltip: '分割线',
            onPressed: () => _insertBlock('\n---\n'),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbarButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    double? fontSize,
  }) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        icon: Icon(icon, size: 20),
        onPressed: onPressed,
        splashRadius: 20,
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 24,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: Colors.grey.withValues(alpha: 0.3),
    );
  }
}
