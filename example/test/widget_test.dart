// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:chatwoot_example/main.dart';

void main() {
  testWidgets('Chatwoot example app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ChatwootExampleApp());

    // Verify that our app loads properly.
    expect(find.text('Chatwoot SDK Example'), findsOneWidget);
    expect(find.text('Connection Status'), findsOneWidget);
    expect(find.text('Actions'), findsOneWidget);

    // Verify that action buttons are present.
    expect(find.text('Send Message'), findsOneWidget);
    expect(find.text('Update Presence'), findsOneWidget);
    expect(find.text('Load Messages'), findsOneWidget);
    expect(find.text('Clear Data'), findsOneWidget);
    expect(find.text('Custom Flutter Chat'), findsOneWidget);
  });
}
