import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:kincircle/models/user_model.dart';
import 'package:kincircle/services/family_snapshot_service.dart';
import 'package:kincircle/widgets/dashboard/family_briefing_row.dart';

void main() {
  group('FamilySnapshotService Unit Tests', () {
    final now = DateTime(2026, 8, 30, 12, 0, 0);

    final needsHelpMember = AppUser(
      uid: 'u-sos',
      displayName: 'Alice SOS',
      needsHelp: true,
      lastKnownLocation: const LatLng(30.0, 31.0),
      lastUpdated: now.subtract(const Duration(minutes: 5)),
    );

    final staleMember = AppUser(
      uid: 'u-stale',
      displayName: 'Bob Stale',
      needsHelp: false,
      lastKnownLocation: const LatLng(30.0, 31.0),
      lastUpdated: now.subtract(const Duration(hours: 4)),
    );

    final staleNullMember = AppUser(
      uid: 'u-null',
      displayName: 'Null Date',
      needsHelp: false,
      lastUpdated: null,
    );

    final movingMember = AppUser(
      uid: 'u-moving',
      displayName: 'Carol Moving',
      needsHelp: false,
      lastKnownLocation: const LatLng(30.0, 31.0),
      lastUpdated: now.subtract(const Duration(minutes: 10)),
    );

    final safeMember = AppUser(
      uid: 'u-safe',
      displayName: 'Dave Safe',
      needsHelp: false,
      lastKnownLocation: const LatLng(30.0, 31.0),
      lastUpdated: now.subtract(const Duration(minutes: 45)),
    );

    final safeNoLocMember = AppUser(
      uid: 'u-safenoloc',
      displayName: 'Eve Safe No Loc',
      needsHelp: false,
      lastKnownLocation: null,
      lastUpdated: now.subtract(const Duration(minutes: 5)),
    );

    test('1. classifyMember: needsHelp -> needsHelp, stale -> stale, moving -> moving, safe -> safe', () {
      expect(classifyMember(needsHelpMember, now), equals('needsHelp'));
      expect(classifyMember(staleMember, now), equals('stale'));
      expect(classifyMember(staleNullMember, now), equals('stale'));
      expect(classifyMember(movingMember, now), equals('moving'));
      expect(classifyMember(safeMember, now), equals('safe'));
      expect(classifyMember(safeNoLocMember, now), equals('safe'));
    });

    test('2. getSnapshot: 4 members (1 needsHelp, 1 moving, 1 stale, 1 safe) returns correct counts and lists', () async {
      final members = [needsHelpMember, movingMember, staleMember, safeMember];
      final snapshot = await FamilySnapshotService.getSnapshot(
        familyId: 'fam-1',
        members: members,
        now: now,
      );

      expect(snapshot.needsHelpCount, equals(1));
      expect(snapshot.movingCount, equals(1));
      expect(snapshot.staleCount, equals(1));
      expect(snapshot.safeCount, equals(1));

      expect(snapshot.needsHelpMembers.first.uid, equals('u-sos'));
      expect(snapshot.movingMembers.first.uid, equals('u-moving'));
      expect(snapshot.staleMembers.first.uid, equals('u-stale'));
      expect(snapshot.safeMembers.first.uid, equals('u-safe'));
    });
  });

  group('FamilyBriefingRow Widget Tests', () {
    final now = DateTime(2026, 8, 30, 12, 0, 0);

    final safeMember = AppUser(
      uid: 'u-safe',
      displayName: 'Dave Safe',
      needsHelp: false,
      lastKnownLocation: const LatLng(30.0, 31.0),
      lastUpdated: now.subtract(const Duration(minutes: 45)),
    );

    final movingMember = AppUser(
      uid: 'u-moving',
      displayName: 'Carol Moving',
      needsHelp: false,
      lastKnownLocation: const LatLng(30.0, 31.0),
      lastUpdated: now.subtract(const Duration(minutes: 10)),
    );

    final staleMember = AppUser(
      uid: 'u-stale',
      displayName: 'Bob Stale',
      needsHelp: false,
      lastKnownLocation: const LatLng(30.0, 31.0),
      lastUpdated: now.subtract(const Duration(hours: 4)),
    );

    final needsHelpMember = AppUser(
      uid: 'u-sos',
      displayName: 'Alice SOS',
      needsHelp: true,
      lastKnownLocation: const LatLng(30.0, 31.0),
      lastUpdated: now.subtract(const Duration(minutes: 5)),
    );

    testWidgets('3. widget renders 3 cards when no needsHelp, 4 cards when needsHelp exists', (WidgetTester tester) async {
      // 3 cards scenario
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FamilyBriefingRow(
              familyId: 'fam-1',
              members: [safeMember, movingMember, staleMember],
              now: now,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('briefing_card_safe')), findsOneWidget);
      expect(find.byKey(const Key('briefing_card_moving')), findsOneWidget);
      expect(find.byKey(const Key('briefing_card_stale')), findsOneWidget);
      expect(find.byKey(const Key('briefing_card_needsHelp')), findsNothing);

      // 4 cards scenario (with needsHelp member)
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FamilyBriefingRow(
              familyId: 'fam-1',
              members: [safeMember, movingMember, staleMember, needsHelpMember],
              now: now,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('briefing_card_needsHelp')), findsOneWidget);
      expect(find.byKey(const Key('briefing_card_safe')), findsOneWidget);
      expect(find.byKey(const Key('briefing_card_moving')), findsOneWidget);
      expect(find.byKey(const Key('briefing_card_stale')), findsOneWidget);
    });

    testWidgets('4. tapping a card shows bottom sheet with correct member names', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FamilyBriefingRow(
              familyId: 'fam-1',
              members: [safeMember, movingMember, staleMember, needsHelpMember],
              now: now,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Safe card
      await tester.tap(find.byKey(const Key('briefing_card_safe')));
      await tester.pumpAndSettle();

      expect(find.text('Safe Members (1)'), findsOneWidget);
      expect(find.text('Dave Safe'), findsOneWidget);

      // Dismiss sheet
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      // Tap Needs Help card
      await tester.tap(find.byKey(const Key('briefing_card_needsHelp')));
      await tester.pumpAndSettle();

      expect(find.text('Needs Help (1)'), findsOneWidget);
      expect(find.text('Alice SOS'), findsOneWidget);
      expect(find.text('Check in'), findsOneWidget);
    });
  });
}
