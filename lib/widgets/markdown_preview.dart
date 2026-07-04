import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:flutter_highlighter/themes/github.dart';
import 'package:highlighter/highlighter.dart' show highlight, Node;

class MarkdownPreview extends StatelessWidget {
  final String data;
  final ScrollController? scrollController;

  const MarkdownPreview({
    super.key,
    required this.data,
    this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: Markdown(
        data: data,
        controller: scrollController,
        selectable: true,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        syntaxHighlighter: _CustomSyntaxHighlighter(theme: githubTheme),
        extensionSet: md.ExtensionSet(
          md.ExtensionSet.gitHubFlavored.blockSyntaxes,
          [
            md.EmojiSyntax(),
            ...md.ExtensionSet.gitHubFlavored.inlineSyntaxes,
          ],
        ),
        styleSheet: MarkdownStyleSheet(
          p: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.6),
          h1: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.bold,
                height: 1.3,
              ),
          h2: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                height: 1.3,
              ),
          h3: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                height: 1.3,
              ),
          h4: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
          h5: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
          h6: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
          code: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontFamily: 'monospace',
                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
          codeblockPadding: const EdgeInsets.all(12),
          codeblockDecoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          blockquote: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).textTheme.bodyLarge?.color?.withValues(alpha: 0.7),
                fontStyle: FontStyle.italic,
              ),
          blockquoteDecoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: Theme.of(context).colorScheme.primary,
                width: 4,
              ),
            ),
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          ),
          blockquotePadding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          tableBorder: TableBorder.all(
            color: Theme.of(context).dividerColor,
            width: 1,
          ),
          tableHead: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
          tableBody: Theme.of(context).textTheme.bodyMedium,
          listBullet: Theme.of(context).textTheme.bodyLarge,
          checkbox: Theme.of(context).textTheme.bodyLarge,
          horizontalRuleDecoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: Theme.of(context).dividerColor,
                width: 1,
              ),
            ),
          ),
          img: const TextStyle(),
          a: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            decoration: TextDecoration.underline,
          ),
        ),
        onTapLink: (text, href, title) {
          // Handle link tapping
          if (href != null) {
            // You can launch URL here with url_launcher
          }
        },
        imageBuilder: (uri, title, alt) {
          final uriStr = uri.toString();
          // Local file path or content URI → use Image.file
          if (uri.scheme == 'file' || uri.scheme == 'content' ||
              (!uri.hasScheme && !uriStr.startsWith('http'))) {
            return Image.file(
              File(uriStr),
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Row(
                    children: [
                      const Icon(Icons.broken_image, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        alt ?? '图片未找到',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                );
              },
            );
          }
          // Network image
          return Image.network(
            uriStr,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                padding: const EdgeInsets.all(16),
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Row(
                  children: [
                    const Icon(Icons.broken_image, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      alt ?? '图片未找到',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _CustomSyntaxHighlighter extends SyntaxHighlighter {
  final Map<String, TextStyle> theme;

  _CustomSyntaxHighlighter({this.theme = const {}});

  @override
  TextSpan format(String source) {
    if (source.isEmpty) {
      return const TextSpan(text: '');
    }

    try {
      final result = highlight.parse(source);
      final nodes = result.nodes;
      if (nodes == null || nodes.isEmpty) {
        return TextSpan(
          style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
          text: source,
        );
      }
      return TextSpan(
        style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
        children: _convert(nodes),
      );
    } catch (e) {
      return TextSpan(
        style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
        text: source,
      );
    }
  }

  List<TextSpan> _convert(List<Node> nodes) {
    final spans = <TextSpan>[];
    List<TextSpan> currentSpans = spans;
    final stack = <List<TextSpan>>[];

    void traverse(Node node) {
      if (node.value != null) {
        currentSpans.add(node.className == null
            ? TextSpan(text: node.value)
            : TextSpan(text: node.value, style: theme[node.className!]));
      } else if (node.children != null) {
        final tmp = <TextSpan>[];
        currentSpans.add(
          TextSpan(children: tmp, style: theme[node.className]),
        );
        stack.add(currentSpans);
        currentSpans = tmp;

        for (final child in node.children!) {
          traverse(child);
        }
        currentSpans = stack.isEmpty ? spans : stack.removeLast();
      }
    }

    for (final node in nodes) {
      traverse(node);
    }

    return spans;
  }
}
