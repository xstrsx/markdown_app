import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:md_editor/export/headless_webview_render.dart';

class FakeBridge implements HeadlessSvgBridge {
  final String? svg;
  bool disposed = false;

  FakeBridge(this.svg);

  @override
  Future<String?> render(String type, String content) async => svg;

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}

void main() {
  test('creates and disposes Android bridge only for a render', () async {
    var created = 0;
    late FakeBridge bridge;
    final renderer = HeadlessWebViewRenderer(
      platform: TargetPlatform.android,
      bridgeFactory: () {
        created++;
        bridge = FakeBridge('<svg/>');
        return bridge;
      },
    );

    expect(created, 0);
    final result = await renderer.renderToSvg('latex-inline', 'x^2');

    expect(created, 1);
    expect(result.svg, '<svg/>');
    expect(bridge.disposed, isTrue);
  });

  test('returns the exact Windows WebView2 fallback without rendering', () async {
    var rendered = false;
    final renderer = HeadlessWebViewRenderer(
      platform: TargetPlatform.windows,
      webView2Availability: () async => false,
      bridgeFactory: () {
        rendered = true;
        return FakeBridge('<svg/>');
      },
    );

    final result = await renderer.renderToSvg('mermaid', 'graph TD; A-->B');

    expect(rendered, isFalse);
    expect(result.svg, isNull);
    expect(result.failure, SvgRenderFailureKind.webView2Unavailable);
    expect(result.warning,
        '当前Windows缺少WebView2运行时，无法渲染LaTeX公式和Mermaid图表，仅导出普通文本内容');
  });

  test('converts bridge exceptions into a render failure', () async {
    final renderer = HeadlessWebViewRenderer(
      platform: TargetPlatform.android,
      bridgeFactory: () => _ThrowingBridge(),
    );

    final result = await renderer.renderToSvg('latex-block', 'x');

    expect(result.svg, isNull);
    expect(result.failure, SvgRenderFailureKind.renderFailed);
  });
}

class _ThrowingBridge implements HeadlessSvgBridge {
  @override
  Future<String?> render(String type, String content) =>
      Future<String?>.error(StateError('render failed'));

  @override
  Future<void> dispose() async {}
}
