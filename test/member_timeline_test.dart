import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kincircle/models/user_model.dart';
import 'package:kincircle/screens/member_timeline_screen.dart';
import 'package:kincircle/services/member_timeline_service.dart';

void main() {
  group('1. mergeAndSort Unit Tests', () {
    test('mixed lists sort descending by timestamp with nulls placed last', () {
      final now = DateTime(2026, 8, 31, 12, 0, 0);
      final e1 = TimelineEvent(
        type: 'checkin',
        title: 'Check-in 1',
        subtitle: '',
        timestamp: now.subtract(const Duration(hours: 2)),
      );
      final e2 = TimelineEvent(
        type: 'sos',
        title: 'SOS Alert',
        subtitle: '',
        timestamp: now.subtract(const Duration(minutes: 30)),
      );
      const e3 = TimelineEvent(
        type: 'alert',
        title: 'Unknown Time Alert',
        subtitle: '',
        timestamp: null,
      );
      final e4 = TimelineEvent(
        type: 'checkin',
        title: 'Check-in 2',
        subtitle: '',
        timestamp: now,
      );

      final result = MemberTimelineService.mergeAndSort([e1, e3], [e2, e4]);

      expect(result.length, equals(4));
      expect(result[0], equals(e4)); // newest: now
      expect(result[1], equals(e2)); // 30m ago
      expect(result[2], equals(e1)); // 2h ago
      expect(result[3], equals(e3)); // null timestamp at end
    });

    test('empty inputs return empty list', () {
      final result = MemberTimelineService.mergeAndSort([], []);
      expect(result, isEmpty);
    });
  });

  group('2. Alert Doc Mapping Unit Tests', () {
    test('sos type maps to sos event', () {
      final data = <String, dynamic>{
        'type': 'sos',
        'title': '🚨 SOS — Alex needs help',
        'message': 'Near Central Park',
        'timestamp': null,
      };

      final event = MemberTimelineService.mapAlertDoc(data);
      expect(event.type, equals('sos'));
      expect(event.title, equals('🚨 SOS — Alex needs help'));
      expect(event.subtitle, equals('Near Central Park'));
    });

    test('missing message maps to empty subtitle', () {
      final data = <String, dynamic>{
        'type': 'geofence',
        'title': 'Left Home',
        // message missing
      };

      final event = MemberTimelineService.mapAlertDoc(data);
      expect(event.subtitle, equals(''));
    });

    test('long message is truncated at 80 chars + …', () {
      const longMessage =
          'This is a very long safety alert message that contains detailed instructions and location updates exceeding 80 characters in total length.';
      final data = <String, dynamic>{
        'type': 'alert',
        'title': 'Long Alert',
        'message': longMessage,
      };

      final event = MemberTimelineService.mapAlertDoc(data);
      expect(event.subtitle.length, equals(81)); // 80 + 1 ('…')
      expect(event.subtitle.endsWith('…'), isTrue);
      expect(
        event.subtitle,
        equals('${longMessage.substring(0, 80)}…'),
      );
    });
  });

  group('3. MemberTimelineScreen Widget Tests', () {
    final testMember = AppUser(
      uid: 'user_123',
      displayName: 'Sarah Connor',
    );

    testWidgets('renders colored dots, titles, subtitles, and relative times', (tester) async {
      final now = DateTime.now();
      final events = [
        TimelineEvent(
          type: 'sos',
          title: '🚨 Emergency SOS Triggered',
          subtitle: 'Location shared with circle',
          timestamp: now.subtract(const Duration(minutes: 5)),
        ),
        TimelineEvent(
          type: 'checkin',
          title: "Checked in — I'm OK",
          subtitle: '',
          timestamp: now.subtract(const Duration(hours: 1)),
        ),
        TimelineEvent(
          type: 'streak',
          title: '7-Day Streak Achieved',
          subtitle: 'Daily check-in completed',
          timestamp: now.subtract(const Duration(hours: 3)),
        ),
        TimelineEvent(
          type: 'geofence',
          title: 'Arrived at School',
          subtitle: 'Central High School',
          timestamp: now.subtract(const Duration(hours: 5)),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: MemberTimelineScreen(
            member: testMember,
            familyId: 'family_1',
            timelineProvider: ({required String uid, required String familyId}) async {
              return events;
            },
          ),
        ),
      );

      // Pump to resolve future
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text("Sarah's today"), findsOneWidget);
      expect(find.text('🚨 Emergency SOS Triggered'), findsOneWidget);
      expect(find.text("Checked in — I'm OK"), findsOneWidget);
      expect(find.text('7-Day Streak Achieved'), findsOneWidget);
      expect(find.text('Arrived at School'), findsOneWidget);
      expect(find.text('Location shared with circle'), findsOneWidget);
      expect(find.text('Central High School'), findsOneWidget);
    });

    testWidgets('renders empty state copy when no events today', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MemberTimelineScreen(
            member: testMember,
            familyId: 'family_1',
            timelineProvider: ({required String uid, required String familyId}) async {
              return [];
            },
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('No activity yet today'), findsOneWidget);
      expect(
        find.text('Check-ins, alerts and place visits will show here'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.timeline), findsOneWidget);
    });

    testWidgets('renders error state when future fails', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MemberTimelineScreen(
            member: testMember,
            familyId: 'family_1',
            timelineProvider: ({required String uid, required String familyId}) async {
              throw Exception('Network error');
            },
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text("Couldn't load today's activity"), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });
  });
}
