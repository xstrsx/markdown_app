import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:md_editor/widgets/storage_choice_dialog.dart';

void main() {
  testWidgets('offers local and cloud storage choices', (tester) async {
    FileStorageChoice? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return FilledButton(
              onPressed: () async {
                result = await showStorageChoiceDialog(context);
              },
              child: const Text('打开'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    expect(find.text('本地'), findsOneWidget);
    expect(find.text('云端'), findsOneWidget);

    await tester.tap(find.text('云端'));
    await tester.pumpAndSettle();
    expect(result, FileStorageChoice.webDav);
  });
}
