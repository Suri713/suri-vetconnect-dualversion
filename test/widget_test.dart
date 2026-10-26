import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetconnect/business/pages/business_search.dart';

void main() {
  testWidgets('sparkle button invokes the separate AI search action', (
    tester,
  ) async {
    var opened = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BusinessSearch(onAiSearchTap: () => opened = true),
        ),
      ),
    );
    await tester.tap(find.byTooltip('AI Search'));
    expect(opened, isTrue);
  });

  testWidgets(
    'failed search shows an error instead of an empty result message',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BusinessSearch(
              onSearch: (_) async => throw StateError('Connection interrupted'),
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), 'coffee');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.text('SEARCH ERROR'), findsOneWidget);
      expect(find.text('NO RESULTS'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    },
  );
}
