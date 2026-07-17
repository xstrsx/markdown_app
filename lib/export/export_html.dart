import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:markdown/markdown.dart' as md;

import 'markdown_ast_parser.dart';

class HtmlExportResult {
  final bool isSuccess;
  final String outputPath;
  final String? error;

  const HtmlExportResult._({
    required this.isSuccess,
    required this.outputPath,
    this.error,
  });

  const HtmlExportResult.success(String outputPath)
      : this._(isSuccess: true, outputPath: outputPath);

  const HtmlExportResult.failure(String outputPath, String error)
      : this._(isSuccess: false, outputPath: outputPath, error: error);
}

/// Converts Markdown to a self-contained HTML document shell.
///
/// The document intentionally keeps LaTeX and Mermaid as source text. The
/// browser-side scripts render them when the CDN is reachable.
String markdownToHtml(String markdown, {String? title}) {
  try {
    final nodes =
        md.Document(extensionSet: md.ExtensionSet.gitHubWeb).parse(markdown);
    final specialNodes = MarkdownAstParser.parse(markdown).renderQueue;
    final mermaidSources = specialNodes
        .where((node) => node.renderType == 'mermaid')
        .map((node) => node.content)
        .toSet();
    final body = _renderNodes(nodes, mermaidSources: mermaidSources);
    return _documentHtml(
      title: title?.trim().isNotEmpty == true ? title!.trim() : 'Markdown文档',
      body: body,
    );
  } catch (error, stackTrace) {
    debugPrint('HTML Markdown 解析失败: $error\n$stackTrace');
    return _documentHtml(
      title: title?.trim().isNotEmpty == true ? title!.trim() : 'Markdown文档',
      body: '<p class="export-error">${_escapeHtml(markdown)}</p>',
    );
  }
}

/// Writes an HTML export to [outputPath] without starting a WebView.
Future<HtmlExportResult> exportMarkdownToHtml(
  String markdown,
  String outputPath, {
  String? title,
}) async {
  try {
    final html = markdownToHtml(markdown, title: title);
    await File(outputPath).writeAsString(html, encoding: utf8, flush: true);
    return HtmlExportResult.success(outputPath);
  } catch (error, stackTrace) {
    debugPrint('HTML 文件写入失败: $error\n$stackTrace');
    return HtmlExportResult.failure(outputPath, error.toString());
  }
}

String _renderNodes(
  Iterable<md.Node> nodes, {
  Set<String> mermaidSources = const <String>{},
}) {
  final buffer = StringBuffer();
  for (final node in nodes) {
    if (node is md.Element) {
      buffer.write(_renderBlock(node, mermaidSources));
    } else if (node is md.Text && node.text.trim().isNotEmpty) {
      buffer.write('<p>${_renderInlineText(node.text)}</p>');
    }
  }
  return buffer.toString();
}

String _renderBlock(md.Element node, Set<String> mermaidSources) {
  switch (node.tag) {
    case 'h1':
    case 'h2':
    case 'h3':
    case 'h4':
    case 'h5':
    case 'h6':
      return '<${node.tag}>${_renderInlineNodes(node.children)}</${node.tag}>';
    case 'p':
      return '<p>${_renderInlineNodes(node.children)}</p>';
    case 'ul':
    case 'ol':
      return '<${node.tag}>${_renderListItems(node.children, mermaidSources)}</${node.tag}>';
    case 'blockquote':
      return '<blockquote>${_renderNodes(node.children ?? const [], mermaidSources: mermaidSources)}</blockquote>';
    case 'pre':
      return _renderCodeBlock(node, mermaidSources);
    case 'table':
      return _renderTable(node);
    case 'img':
      return _renderImage(node);
    case 'hr':
      return '<hr>';
    default:
      return _renderNodes(node.children ?? const [],
          mermaidSources: mermaidSources);
  }
}

String _renderListItems(
  List<md.Node>? children,
  Set<String> mermaidSources,
) {
  final buffer = StringBuffer();
  for (final child in children ?? const <md.Node>[]) {
    if (child is! md.Element || child.tag != 'li') continue;
    final inlineChildren = <md.Node>[];
    final nestedBlocks = <md.Element>[];
    for (final node in child.children ?? const <md.Node>[]) {
      if (node is md.Element && (node.tag == 'ul' || node.tag == 'ol')) {
        nestedBlocks.add(node);
      } else {
        inlineChildren.add(node);
      }
    }
    buffer.write('<li>${_renderInlineNodes(inlineChildren)}');
    for (final nested in nestedBlocks) {
      buffer.write(_renderBlock(nested, mermaidSources));
    }
    buffer.write('</li>');
  }
  return buffer.toString();
}

String _renderCodeBlock(md.Element node, Set<String> mermaidSources) {
  final code = node.children?.whereType<md.Element>().firstOrNull;
  final language = (code?.attributes['class'] ?? node.attributes['class'])
      ?.replaceFirst('language-', '');
  final content = _decodeMarkdownText(code?.textContent ?? node.textContent);
  if (language?.toLowerCase() == 'mermaid' ||
      mermaidSources.contains(content)) {
    return '<div class="mermaid">${_escapeHtml(content)}</div>';
  }
  final className =
      language == null ? '' : ' class="language-${_escapeAttribute(language)}"';
  return '<pre><code$className>${_escapeHtml(content)}</code></pre>';
}

String _renderTable(md.Element node) {
  final buffer = StringBuffer('<table>');
  for (final section in node.children ?? const <md.Node>[]) {
    if (section is! md.Element ||
        (section.tag != 'thead' && section.tag != 'tbody')) {
      continue;
    }
    buffer.write('<${section.tag}>');
    for (final row in section.children ?? const <md.Node>[]) {
      if (row is! md.Element || row.tag != 'tr') continue;
      buffer.write('<tr>');
      for (final cell in row.children ?? const <md.Node>[]) {
        if (cell is! md.Element || (cell.tag != 'th' && cell.tag != 'td')) {
          continue;
        }
        buffer.write(
            '<${cell.tag}>${_renderInlineNodes(cell.children)}</${cell.tag}>');
      }
      buffer.write('</tr>');
    }
    buffer.write('</${section.tag}>');
  }
  buffer.write('</table>');
  return buffer.toString();
}

String _renderImage(md.Element node) {
  final source = _escapeAttribute(node.attributes['src'] ?? '');
  final alt = _escapeAttribute(node.attributes['alt'] ?? '');
  return '<img src="$source" alt="$alt" loading="lazy">';
}

String _renderInlineNodes(List<md.Node>? nodes) {
  final buffer = StringBuffer();
  for (final node in nodes ?? const <md.Node>[]) {
    if (node is md.Text) {
      buffer.write(_renderInlineText(node.text));
      continue;
    }
    if (node is! md.Element) continue;
    final content = _renderInlineNodes(node.children);
    switch (node.tag) {
      case 'strong':
      case 'b':
        buffer.write('<strong>$content</strong>');
        break;
      case 'em':
      case 'i':
        buffer.write('<em>$content</em>');
        break;
      case 'del':
      case 's':
      case 'strike':
        buffer.write('<del>$content</del>');
        break;
      case 'code':
        buffer.write('<code>$content</code>');
        break;
      case 'a':
        final href = _escapeAttribute(node.attributes['href'] ?? '');
        buffer.write('<a href="$href">$content</a>');
        break;
      case 'br':
        buffer.write('<br>');
        break;
      case 'img':
        buffer.write(_renderImage(node));
        break;
      default:
        buffer.write(content);
        break;
    }
  }
  return buffer.toString();
}

String _renderInlineText(String text) => _escapeHtml(text);

String _documentHtml({required String title, required String body}) =>
    r'''<!DOCTYPE html>
<html lang="zh-CN">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>__HTML_TITLE__</title>
  <link rel="stylesheet" href="https://s4.zstatic.net/ajax/libs/KaTeX/0.16.9/katex.min.css">
  <script src="https://s4.zstatic.net/ajax/libs/KaTeX/0.16.9/katex.min.js"></script>
  <script src="https://s4.zstatic.net/ajax/libs/mermaid/11.12.0/mermaid.min.js"></script>
  <style>
    :root { color-scheme: light; }
    body {
      box-sizing: border-box;
      max-width: 900px;
      margin: 0 auto;
      padding: 24px;
      color: #202124;
      background: #fff;
      font-family: "Noto Sans SC", system-ui, sans-serif;
      font-size: 16px;
      line-height: 1.7;
    }
    h1, h2, h3, h4, h5, h6 { line-height: 1.3; margin: 1.2em 0 .55em; }
    p { margin: 0 0 1em; }
    a { color: #1769aa; }
    blockquote {
      margin: 1em 0;
      padding: .35em 1em;
      border-left: 4px solid #b8c1cc;
      color: #4f5965;
      background: #f5f6f7;
    }
    pre, code {
      font-family: "Cascadia Mono", "SFMono-Regular", Consolas, monospace;
    }
    code {
      padding: .12em .35em;
      border-radius: 3px;
      background: #eef0f2;
    }
    pre {
      overflow-x: auto;
      margin: 1em 0;
      padding: 14px 16px;
      border-radius: 5px;
      background: #f1f3f4;
      line-height: 1.5;
    }
    pre code { padding: 0; background: transparent; }
    table { width: 100%; margin: 1em 0; border-collapse: collapse; }
    th, td { padding: 7px 9px; border: 1px solid #d7dce1; text-align: left; }
    th { background: #f1f3f4; }
    img { max-width: 100%; height: auto; }
    .latex-block { margin: 1em 0; overflow-x: auto; text-align: center; }
    .katex { vertical-align: middle; }
    .mermaid { max-width: 100%; overflow-x: auto; text-align: center; }
    .mermaid svg { max-width: 100%; height: auto; }
    .export-error { white-space: pre-wrap; color: #a33; }
  </style>
</head>
<body>
  <main class="markdown-content">
__HTML_BODY__
  </main>
  <script>
    (function () {
      const inlineFormula = /(?<!\x24)\x24([^\x24\n]+?)\x24(?!\x24)/g;

      function renderBlockFormulas() {
        if (!window.katex) return;
        const blockFormula = /^\s*\x24\x24([\s\S]*?)\x24\x24\s*$/;
        const walker = document.createTreeWalker(
          document.querySelector('.markdown-content'),
          NodeFilter.SHOW_TEXT
        );
        const textNodes = [];
        let node;
        while ((node = walker.nextNode())) {
          const parent = node.parentElement;
          if (!parent || parent.closest('pre, code, .mermaid')) continue;
          if (blockFormula.test(node.nodeValue || '')) textNodes.push(node);
        }
        textNodes.forEach(function (textNode) {
          const source = textNode.nodeValue || '';
          const match = blockFormula.exec(source);
          if (!match) return;
          const element = document.createElement('div');
          element.className = 'latex-block';
          try {
            element.textContent = '';
            window.katex.render(match[1].trim(), element, {
              displayMode: true,
              throwOnError: false
            });
          } catch (_) {
            element.textContent = source;
          }
          const parent = textNode.parentElement;
          const target = parent && parent.tagName === 'P' ? parent : textNode;
          target.parentNode.replaceChild(element, target);
        });
      }

      function renderInlineFormulas() {
        if (!window.katex) return;
        const walker = document.createTreeWalker(
          document.querySelector('.markdown-content'),
          NodeFilter.SHOW_TEXT
        );
        const textNodes = [];
        let node;
        while ((node = walker.nextNode())) {
          const parent = node.parentElement;
          if (!parent || parent.closest('pre, code, .mermaid, .katex, .latex-block')) continue;
          inlineFormula.lastIndex = 0;
          if (inlineFormula.test(node.nodeValue || '')) textNodes.push(node);
        }
        textNodes.forEach(function (textNode) {
          const source = textNode.nodeValue || '';
          const fragment = document.createDocumentFragment();
          let cursor = 0;
          inlineFormula.lastIndex = 0;
          let match;
          while ((match = inlineFormula.exec(source))) {
            fragment.appendChild(document.createTextNode(source.slice(cursor, match.index)));
            const span = document.createElement('span');
            try {
              window.katex.render(match[1].trim(), span, { throwOnError: false });
            } catch (_) {
              span.textContent = match[0];
            }
            fragment.appendChild(span);
            cursor = match.index + match[0].length;
          }
          fragment.appendChild(document.createTextNode(source.slice(cursor)));
          textNode.parentNode.replaceChild(fragment, textNode);
        });
      }

      function renderMermaid() {
        if (!window.mermaid) return;
        window.mermaid.initialize({ startOnLoad: true, theme: 'default', securityLevel: 'strict' });
        if (window.mermaid.run) window.mermaid.run().catch(function (_) {});
      }

      window.addEventListener('load', function () {
        renderBlockFormulas();
        renderInlineFormulas();
        renderMermaid();
      });
    })();
  </script>
</body>
</html>
'''
        .replaceAll('__HTML_TITLE__', _escapeHtml(title))
        .replaceAll(
          '__HTML_BODY__',
          body,
        );

String _escapeHtml(String value) =>
    const HtmlEscape(HtmlEscapeMode.element).convert(value);

String _escapeAttribute(String value) =>
    const HtmlEscape(HtmlEscapeMode.attribute).convert(value);

String _decodeMarkdownText(String value) => value
    .replaceAll('&gt;', '>')
    .replaceAll('&lt;', '<')
    .replaceAll('&amp;', '&')
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'");
