import 'dart:io';
import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:flutter_mermaid/flutter_mermaid.dart';
import 'package:url_launcher/url_launcher.dart';

class MarkdownPreview extends StatelessWidget {
  final String data;
  final ScrollController? scrollController;

  const MarkdownPreview({
    super.key,
    required this.data,
    this.scrollController,
  });

  Future<void> _openLink(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      debugPrint('预览链接不是可打开的网页地址: $url');
      return;
    }

    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened) debugPrint('系统浏览器无法打开预览链接: $url');
    } catch (error, stackTrace) {
      debugPrint('打开预览链接失败: $error\n$stackTrace');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: SingleChildScrollView(
        controller: scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: GptMarkdown(
          data,
          useDollarSignsForLatex: true,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontSize: 16,
                height: 1.6,
              ),
          onLinkTap: (url, title) {
            _openLink(url);
          },
          codeBuilder: (context, lang, code, closed) {
            if (lang.toLowerCase() == "mermaid") {
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: MermaidDiagram(code: code),
              );
            }
            // Default code block rendering
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SelectableText(
                  code,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                ),
              ),
            );
          },
          imageBuilder: (context, imageUrl, width, height) {
            final uri = Uri.tryParse(imageUrl);

            if (uri != null &&
                (uri.scheme == 'file' ||
                    uri.scheme == 'content' ||
                    (!uri.hasScheme && !imageUrl.startsWith('http')))) {
              return Image.file(
                File(imageUrl),
                width: width,
                height: height,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: const Row(
                      children: [
                        Icon(Icons.broken_image, size: 20),
                        SizedBox(width: 8),
                        Text('图片未找到'),
                      ],
                    ),
                  );
                },
              );
            }

            return Image.network(
              imageUrl,
              width: width,
              height: height,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  color:
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: const Row(
                    children: [
                      Icon(Icons.broken_image, size: 20),
                      SizedBox(width: 8),
                      Text('图片未找到'),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
