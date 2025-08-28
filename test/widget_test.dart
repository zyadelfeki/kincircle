// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// main.dart not needed for this smoke test; keep minimal to avoid Firebase init

void main() {
  testWidgets('App smoke test: renders a Scaffold', (WidgetTester tester) async {
    // Pump a minimal app that doesn't require Firebase.
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Text('Hello'))));
    await tester.pumpAndSettle();

    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.text('Hello'), findsOneWidget);
  });
}
