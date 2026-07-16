import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

const windowsWebView2Warning =
    '当前Windows缺少WebView2运行时，无法渲染LaTeX公式和Mermaid图表，仅导出普通文本内容';

enum SvgRenderFailureKind {
  none,
  webView2Unavailable,
  renderFailed,
}

class SvgRenderResult {
  final String? svg;
  final SvgRenderFailureKind failure;
  final String? warning;

  const SvgRenderResult({
    required this.svg,
    this.failure = SvgRenderFailureKind.none,
    this.warning,
  });

  bool get isSuccess => svg != null && failure == SvgRenderFailureKind.none;
}

abstract class SvgRenderer {
  Future<SvgRenderResult> renderToSvg(String type, String content);
}

abstract class HeadlessSvgBridge {
  Future<String?> render(String type, String content);

  Future<void> dispose();
}

typedef HeadlessSvgBridgeFactory = FutureOr<HeadlessSvgBridge> Function();
typedef WebView2Availability = Future<bool> Function();

class HeadlessWebViewRenderer implements SvgRenderer {
  final TargetPlatform platform;
  final HeadlessSvgBridgeFactory bridgeFactory;
  final WebView2Availability webView2Availability;

  const HeadlessWebViewRenderer({
    required this.platform,
    this.bridgeFactory = _createProductionBridge,
    this.webView2Availability = _checkWebView2,
  });

  @override
  Future<SvgRenderResult> renderToSvg(String type, String content) async {
    if (platform == TargetPlatform.windows) {
      try {
        if (!await webView2Availability()) {
          return const SvgRenderResult(
            svg: null,
            failure: SvgRenderFailureKind.webView2Unavailable,
            warning: windowsWebView2Warning,
          );
        }
      } catch (error) {
        debugPrint('WebView2 检测失败: $error');
        return const SvgRenderResult(
          svg: null,
          failure: SvgRenderFailureKind.webView2Unavailable,
          warning: windowsWebView2Warning,
        );
      }
    }

    HeadlessSvgBridge? bridge;
    try {
      bridge = await bridgeFactory();
      final svg = await bridge.render(type, content);
      if (svg == null || svg.trim().isEmpty) {
        return const SvgRenderResult(
          svg: null,
          failure: SvgRenderFailureKind.renderFailed,
        );
      }
      return SvgRenderResult(svg: svg);
    } catch (error) {
      debugPrint('SVG 渲染失败: $error');
      return const SvgRenderResult(
        svg: null,
        failure: SvgRenderFailureKind.renderFailed,
      );
    } finally {
      try {
        await bridge?.dispose();
      } catch (error) {
        debugPrint('无头 WebView 销毁失败: $error');
      }
    }
  }

  static Future<HeadlessSvgBridge> _createProductionBridge() async {
    WebViewEnvironment? webViewEnvironment;
    if (defaultTargetPlatform == TargetPlatform.windows) {
      // WebView2 must be initialized before a Windows headless view is run.
      webViewEnvironment = await WebViewEnvironment.create();
    }
    return _InAppWebViewSvgBridge(webViewEnvironment: webViewEnvironment);
  }

  static Future<bool> _checkWebView2() async {
    return (await WebViewEnvironment.getAvailableVersion()) != null;
  }
}

class _InAppWebViewSvgBridge implements HeadlessSvgBridge {
  late final WebViewEnvironment? _webViewEnvironment;
  late final HeadlessInAppWebView _webView;
  final Map<int, Completer<String?>> _pendingResults = {};
  final Completer<InAppWebViewController> _controllerCompleter =
      Completer<InAppWebViewController>();
  final Completer<void> _loadCompleter = Completer<void>();
  var _nextRequestId = 0;

  _InAppWebViewSvgBridge({WebViewEnvironment? webViewEnvironment}) {
    _webViewEnvironment = webViewEnvironment;
    _webView = HeadlessInAppWebView(
      webViewEnvironment: webViewEnvironment,
      initialFile: 'assets/render_assets/render.html',
      onWebViewCreated: (controller) {
        // The page remains offline; all rendering libraries are local assets.
        controller.addJavaScriptHandler(
          handlerName: 'svgReady',
          callback: (arguments) {
            _completeResult(arguments, error: false);
            return null;
          },
        );
        controller.addJavaScriptHandler(
          handlerName: 'svgError',
          callback: (arguments) {
            _completeResult(arguments, error: true);
            return null;
          },
        );
        _controllerCompleter.complete(controller);
      },
      onLoadStop: (controller, url) {
        if (!_loadCompleter.isCompleted) _loadCompleter.complete();
      },
      onReceivedError: (controller, request, error) {
        if (!_loadCompleter.isCompleted) {
          _loadCompleter.completeError(StateError(error.description));
        }
      },
    );
  }

  @override
  Future<String?> render(String type, String content) async {
    await _webView.run();
    final controller = await _controllerCompleter.future;
    await _loadCompleter.future;
    final requestId = ++_nextRequestId;
    final result = Completer<String?>();
    _pendingResults[requestId] = result;
    try {
      await controller.evaluateJavascript(
        source:
            'window.flutterRenderSvg(${jsonEncode(type)}, ${jsonEncode(content)}, $requestId)',
      );
      return await result.future.timeout(const Duration(seconds: 30));
    } finally {
      _pendingResults.remove(requestId);
    }
  }

  void _completeResult(List<dynamic> arguments, {required bool error}) {
    if (arguments.isEmpty) return;
    final requestId = (arguments[0] as num?)?.toInt();
    final completer = requestId == null ? null : _pendingResults[requestId];
    if (completer == null || completer.isCompleted) return;
    if (error) {
      completer.completeError(StateError(
          arguments.length > 1 ? arguments[1].toString() : 'SVG 渲染失败'));
    } else {
      completer.complete(arguments.length > 1 ? arguments[1].toString() : null);
    }
  }

  @override
  Future<void> dispose() async {
    await _webView.dispose();
    await _webViewEnvironment?.dispose();
  }
}
