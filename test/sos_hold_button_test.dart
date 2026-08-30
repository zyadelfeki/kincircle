import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kincircle/widgets/dashboard/sos_hold_button.dart';

void main() {
  group('SosHoldButton Widget Tests', () {
    testWidgets('Renders idle SOS (Hold) button by default', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SosHoldButton(
              holdDuration: Duration(seconds: 3),
            ),
          ),
        ),
      );

      expect(find.text('SOS (Hold)'), findsOneWidget);
      expect(find.byIcon(Icons.sos_rounded), findsOneWidget);
    });

    testWidgets('Single tap does NOT trigger emergency response', (tester) async {
      bool triggered = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SosHoldButton(
              holdDuration: const Duration(seconds: 3),
              onTriggered: () async {
                triggered = true;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.byType(SosHoldButton));
      await tester.pumpAndSettle();

      expect(triggered, false);
      expect(find.text('SOS (Hold)'), findsOneWidget);
    });

    testWidgets('Releasing early cancels hold without triggering', (tester) async {
      bool triggered = false;
      bool cancelled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SosHoldButton(
              holdDuration: const Duration(seconds: 3),
              onTriggered: () async {
                triggered = true;
              },
              onCancel: () {
                cancelled = true;
              },
            ),
          ),
        ),
      );

      final gesture = await tester.startGesture(tester.getCenter(find.byType(SosHoldButton)));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('HOLD 2s'), findsOneWidget);

      await gesture.up();
      await tester.pump(const Duration(milliseconds: 100));

      expect(triggered, false);
      expect(cancelled, true);
      expect(find.text('SOS (Hold)'), findsOneWidget);
    });

    testWidgets('Holding for full 3 seconds completes and triggers emergency response', (tester) async {
      bool triggered = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SosHoldButton(
              holdDuration: const Duration(seconds: 3),
              onTriggered: () async {
                triggered = true;
              },
            ),
          ),
        ),
      );

      final gesture = await tester.startGesture(tester.getCenter(find.byType(SosHoldButton)));
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(milliseconds: 200));

      expect(triggered, true);
      await gesture.up();
      await tester.pump(const Duration(seconds: 5));
    });
  });
}
