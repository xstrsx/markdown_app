import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('render asset reports async results through the Flutter bridge', () {
    final html = File('assets/render_assets/render.html').readAsStringSync();

    expect(html, contains('flutterRenderSvg'));
    expect(html, contains('__flutterSvgResults'));
    expect(html, contains('callHandler("svgReady"'));
    expect(html, contains('callHandler("svgError"'));
  });
}
