import 'package:markdown/markdown.dart' as md;

enum MarkdownExportNodeType {
  heading,
  paragraph,
  unorderedList,
  orderedList,
  blockquote,
  codeBlock,
  table,
  image,
  horizontalRule,
  latexInline,
  latexBlock,
  mermaid,
  text,
}

abstract class MarkdownExportNode {
  final MarkdownExportNodeType type;

  const MarkdownExportNode(this.type);
}

class MarkdownExportDocument {
  final List<MarkdownExportNode> nodes;
  final List<MarkdownRenderNode> renderQueue;

  const MarkdownExportDocument({
    required this.nodes,
    required this.renderQueue,
  });
}

class MarkdownHeadingNode extends MarkdownExportNode {
  final int level;
  final String text;

  const MarkdownHeadingNode({required this.level, required this.text})
      : super(MarkdownExportNodeType.heading);
}

class MarkdownParagraphNode extends MarkdownExportNode {
  final String text;
  final List<MarkdownInlineNode> inlines;

  const MarkdownParagraphNode({required this.text, required this.inlines})
      : super(MarkdownExportNodeType.paragraph);
}

class MarkdownListNode extends MarkdownExportNode {
  final bool ordered;
  final List<String> items;

  const MarkdownListNode({required this.ordered, required this.items})
      : super(ordered
            ? MarkdownExportNodeType.orderedList
            : MarkdownExportNodeType.unorderedList);
}

class MarkdownBlockquoteNode extends MarkdownExportNode {
  final String text;

  const MarkdownBlockquoteNode(this.text)
      : super(MarkdownExportNodeType.blockquote);
}

class MarkdownCodeBlockNode extends MarkdownExportNode {
  final String content;
  final String? language;

  const MarkdownCodeBlockNode({required this.content, this.language})
      : super(MarkdownExportNodeType.codeBlock);
}

class MarkdownTableNode extends MarkdownExportNode {
  final List<List<String>> rows;

  const MarkdownTableNode(this.rows) : super(MarkdownExportNodeType.table);
}

class MarkdownImageNode extends MarkdownExportNode {
  final String source;
  final String alt;

  const MarkdownImageNode({required this.source, required this.alt})
      : super(MarkdownExportNodeType.image);
}

class MarkdownHorizontalRuleNode extends MarkdownExportNode {
  const MarkdownHorizontalRuleNode() : super(MarkdownExportNodeType.horizontalRule);
}

abstract class MarkdownInlineNode {
  final String text;

  const MarkdownInlineNode(this.text);
}

class MarkdownInlineText extends MarkdownInlineNode {
  const MarkdownInlineText(super.text);
}

class MarkdownInlineFormula extends MarkdownInlineNode {
  const MarkdownInlineFormula(super.text);
}

class MarkdownRenderNode extends MarkdownExportNode {
  final String renderType;
  final String content;

  const MarkdownRenderNode({required this.renderType, required this.content})
      : super(renderType == 'mermaid'
            ? MarkdownExportNodeType.mermaid
            : renderType == 'latex-block'
                ? MarkdownExportNodeType.latexBlock
                : MarkdownExportNodeType.latexInline);
}

class MarkdownMermaidNode extends MarkdownRenderNode {
  const MarkdownMermaidNode(String content)
      : super(renderType: 'mermaid', content: content);
}

class MarkdownAstParser {
  const MarkdownAstParser._();

  static MarkdownExportDocument parse(String source) {
    final parsed = md.Document(extensionSet: md.ExtensionSet.gitHubWeb)
        .parse(source);
    final nodes = <MarkdownExportNode>[];
    final renderQueue = <MarkdownRenderNode>[];
    for (final node in parsed) {
      _appendNode(node, nodes, renderQueue);
    }
    return MarkdownExportDocument(nodes: nodes, renderQueue: renderQueue);
  }

  static void _appendNode(
    md.Node node,
    List<MarkdownExportNode> nodes,
    List<MarkdownRenderNode> renderQueue,
  ) {
    if (node is! md.Element) return;
    switch (node.tag) {
      case 'h1':
      case 'h2':
      case 'h3':
      case 'h4':
      case 'h5':
      case 'h6':
        nodes.add(MarkdownHeadingNode(
          level: int.parse(node.tag.substring(1)),
          text: node.textContent,
        ));
        return;
      case 'p':
        final block = _blockFormula(node.textContent);
        if (block != null) {
          nodes.add(block);
          renderQueue.add(block);
          return;
        }
        final inlines = _parseInlines(node.textContent, renderQueue);
        nodes.add(MarkdownParagraphNode(
          text: node.textContent,
          inlines: inlines,
        ));
        return;
      case 'ul':
      case 'ol':
        nodes.add(MarkdownListNode(
          ordered: node.tag == 'ol',
          items: (node.children ?? const <md.Node>[])
              .whereType<md.Element>()
              .where((child) => child.tag == 'li')
              .map((child) => child.textContent)
              .toList(),
        ));
        return;
      case 'blockquote':
        nodes.add(MarkdownBlockquoteNode(node.textContent));
        return;
      case 'pre':
        final code = node.children?.whereType<md.Element>().firstOrNull;
        final language = code?.attributes['class']?.replaceFirst('language-', '');
        final content = _decodeText(code?.textContent ?? node.textContent);
        if (language?.toLowerCase() == 'mermaid') {
          final mermaid = MarkdownMermaidNode(content);
          nodes.add(mermaid);
          renderQueue.add(mermaid);
        } else {
          nodes.add(MarkdownCodeBlockNode(content: content, language: language));
        }
        return;
      case 'table':
        nodes.add(MarkdownTableNode(_tableRows(node)));
        return;
      case 'img':
        nodes.add(MarkdownImageNode(
          source: node.attributes['src'] ?? '',
          alt: node.attributes['alt'] ?? '',
        ));
        return;
      case 'hr':
        nodes.add(const MarkdownHorizontalRuleNode());
        return;
    }
    for (final child in node.children ?? const <md.Node>[]) {
      _appendNode(child, nodes, renderQueue);
    }
  }

  static MarkdownRenderNode? _blockFormula(String text) {
    final match = RegExp(r'^\s*\$\$\s*\n([\s\S]*?)\n\s*\$\$\s*$')
        .firstMatch(text);
    if (match == null) return null;
    return MarkdownRenderNode(renderType: 'latex-block', content: match.group(1)!);
  }

  static List<MarkdownInlineNode> _parseInlines(
    String text,
    List<MarkdownRenderNode> renderQueue,
  ) {
    final result = <MarkdownInlineNode>[];
    final pattern = RegExp(r'(?<!\$)\$([^$\n]+)\$(?!\$)');
    var cursor = 0;
    for (final match in pattern.allMatches(text)) {
      if (match.start > cursor) {
        result.add(MarkdownInlineText(text.substring(cursor, match.start)));
      }
      final formula = MarkdownRenderNode(
        renderType: 'latex-inline',
        content: match.group(1)!,
      );
      result.add(MarkdownInlineFormula(formula.content));
      renderQueue.add(formula);
      cursor = match.end;
    }
    if (cursor < text.length) result.add(MarkdownInlineText(text.substring(cursor)));
    if (result.isEmpty) result.add(MarkdownInlineText(text));
    return result;
  }

  static List<List<String>> _tableRows(md.Element table) {
    return table.children
            ?.whereType<md.Element>()
            .expand((section) => section.children?.whereType<md.Element>() ??
                const Iterable<md.Element>.empty())
            .map((row) => row.children
                ?.whereType<md.Element>()
                .map((cell) => cell.textContent)
                .toList())
            .whereType<List<String>>()
            .toList() ??
        const <List<String>>[];
  }

  static String _decodeText(String value) => value
      .replaceAll('&gt;', '>')
      .replaceAll('&lt;', '<')
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'");
}
