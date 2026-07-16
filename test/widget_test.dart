import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:md_editor/main.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('App renders main screen with title and action buttons',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();

    expect(find.text('MD 编辑器'), findsOneWidget);

    expect(
      find.text('创建和编辑精美的 Markdown 文档'),
      findsOneWidget,
    );

    expect(find.text('新建 Markdown 文件'), findsOneWidget);
    expect(find.text('打开本地 Markdown 文件'), findsOneWidget);

    expect(find.text('首页'), findsWidgets);
    expect(find.text('历史'), findsWidgets);
  });

  testWidgets('Navigation switches between Home and History pages',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();

    expect(find.text('MD 编辑器'), findsOneWidget);
    expect(find.text('暂无历史'), findsNothing);

    await tester.tap(find.text('历史').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('暂无历史'), findsOneWidget);
    expect(
      find.text('最近编辑的文件将显示在此处'),
      findsOneWidget,
    );

    await tester.tap(find.text('首页').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('MD 编辑器'), findsOneWidget);
  });

  testWidgets('Create new file dialog opens and has correct fields',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();

    await tester.tap(find.text('新建 Markdown 文件'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('新建 Markdown 文件'), findsWidgets);
    expect(find.text('文件名'), findsOneWidget);
    expect(find.text('取消'), findsOneWidget);
    expect(find.text('创建'), findsOneWidget);
  });
}
