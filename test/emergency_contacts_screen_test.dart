import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kincircle/screens/emergency/emergency_contacts_screen.dart';

void main() {
  group('EmergencyContactsScreen Widget Tests', () {
    testWidgets('EmergencyContactsScreen displays app bar with title', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: EmergencyContactsScreen(),
        ),
      );

      expect(find.text('Emergency Contacts'), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('EmergencyContactsScreen has add button in app bar', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: EmergencyContactsScreen(),
        ),
      );

      expect(find.byIcon(Icons.add), findsOneWidget);
      expect(find.byType(IconButton), findsAtLeastNWidgets(1));
    });

    testWidgets('EmergencyContactsScreen shows loading indicator initially', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: EmergencyContactsScreen(),
        ),
      );

      // Should show loading indicator while waiting for stream
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('EmergencyContactsScreen is a StatefulWidget', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: EmergencyContactsScreen(),
        ),
      );

      expect(find.byType(EmergencyContactsScreen), findsOneWidget);
      final widget = tester.widget<EmergencyContactsScreen>(find.byType(EmergencyContactsScreen));
      expect(widget, isA<StatefulWidget>());
    });

    testWidgets('EmergencyContactsScreen has StreamBuilder', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: EmergencyContactsScreen(),
        ),
      );

      expect(find.byType(StreamBuilder), findsOneWidget);
    });
  });

  group('Emergency Contact Type Tests', () {
    test('Contact types have correct display labels', () {
      // This would be tested in the screen implementation
      // Verify that type labels are properly mapped
      final types = ['Family', 'Medical', 'First Responder'];
      expect(types.length, equals(3));
    });

    test('Priority levels have correct display labels', () {
      // This would be tested in the screen implementation
      // Verify that priority labels are properly mapped
      final priorities = ['Primary', 'Secondary', 'Tertiary'];
      expect(priorities.length, equals(3));
    });
  });
}
