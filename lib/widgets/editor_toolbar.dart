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
    
    // Find the start of the current line
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
            tooltip: 'Heading 1',
            onPressed: () => _insertLine('# '),
          ),
          _buildToolbarButton(
            icon: Icons.title,
            tooltip: 'Heading 2',
            onPressed: () => _insertLine('## '),
            fontSize: 14,
          ),
          _buildToolbarButton(
            icon: Icons.title,
            tooltip: 'Heading 3',
            onPressed: () => _insertLine('### '),
            fontSize: 12,
          ),
          _buildDivider(),
          _buildToolbarButton(
            icon: Icons.format_bold,
            tooltip: 'Bold',
            onPressed: () => _insertAround('**', '**', placeholder: 'bold text'),
          ),
          _buildToolbarButton(
            icon: Icons.format_italic,
            tooltip: 'Italic',
            onPressed: () => _insertAround('*', '*', placeholder: 'italic text'),
          ),
          _buildToolbarButton(
            icon: Icons.format_strikethrough,
            tooltip: 'Strikethrough',
            onPressed: () => _insertAround('~~', '~~', placeholder: 'strikethrough'),
          ),
          _buildDivider(),
          _buildToolbarButton(
            icon: Icons.format_list_bulleted,
            tooltip: 'Bullet List',
            onPressed: () => _insertLine('- '),
          ),
          _buildToolbarButton(
            icon: Icons.format_list_numbered,
            tooltip: 'Numbered List',
            onPressed: () => _insertLine('1. '),
          ),
          _buildToolbarButton(
            icon: Icons.check_box,
            tooltip: 'Task List',
            onPressed: () => _insertLine('- [ ] '),
          ),
          _buildDivider(),
          _buildToolbarButton(
            icon: Icons.format_quote,
            tooltip: 'Quote',
            onPressed: () => _insertLine('> '),
          ),
          _buildToolbarButton(
            icon: Icons.code,
            tooltip: 'Inline Code',
            onPressed: () => _insertAround('`', '`', placeholder: 'code'),
          ),
          _buildToolbarButton(
            icon: Icons.code_off,
            tooltip: 'Code Block',
            onPressed: () => _insertBlock('```\ncode block\n```\n'),
          ),
          _buildDivider(),
          _buildToolbarButton(
            icon: Icons.link,
            tooltip: 'Link',
            onPressed: () => _insertAround('[', '](url)', placeholder: 'link text'),
          ),
          _buildToolbarButton(
            icon: Icons.image,
            tooltip: 'Image',
            onPressed: () => _insertBlock('![alt text](image_url)'),
          ),
          _buildDivider(),
          _buildToolbarButton(
            icon: Icons.table_chart,
            tooltip: 'Table',
            onPressed: () => _insertBlock(
              '\n| Header 1 | Header 2 | Header 3 |\n| --- | --- | --- |\n| Cell 1 | Cell 2 | Cell 3 |\n',
            ),
          ),
          _buildToolbarButton(
            icon: Icons.horizontal_rule,
            tooltip: 'Horizontal Rule',
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
