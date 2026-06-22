import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:md_editor/main.dart';

void main() {
  setUp(() {
    // Mock SharedPreferences for tests
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('App renders main screen with title and action buttons', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump(); // Allow async calls to settle

    // Verify the app title is shown
    expect(find.text('Markdown Editor'), findsOneWidget);

    // Verify the subtitle text
    expect(
      find.text('Create and edit beautiful Markdown documents'),
      findsOneWidget,
    );

    // Verify both action buttons exist
    expect(find.text('New Markdown File'), findsOneWidget);
    expect(find.text('Open Local Markdown File'), findsOneWidget);

    // Verify navigation destinations exist
    expect(find.text('Home'), findsWidgets);
    expect(find.text('History'), findsWidgets);
  });

  testWidgets('Navigation switches between Home and History pages', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump(); // Allow async calls to settle

    // Initially on Home page — verify home content
    expect(find.text('Markdown Editor'), findsOneWidget);
    expect(find.text('No History Yet'), findsNothing);

    // Navigate to History page by tapping the nav label
    await tester.tap(find.text('History').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Should now see the History page with empty state
    expect(find.text('No History Yet'), findsOneWidget);
    expect(
      find.text('Your recently edited files will appear here'),
      findsOneWidget,
    );

    // Navigate back to Home
    await tester.tap(find.text('Home').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Should be back on home
    expect(find.text('Markdown Editor'), findsOneWidget);
  });

  testWidgets('Create new file dialog opens and has correct fields', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump(); // Allow async calls to settle

    // Tap "New Markdown File" button
    await tester.tap(find.text('New Markdown File'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Verify dialog shows up
    expect(find.text('New Markdown File'), findsWidgets);
    expect(find.text('File Name'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Create'), findsOneWidget);
  });
}
