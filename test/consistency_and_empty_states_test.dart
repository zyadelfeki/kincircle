import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kincircle/design/kincircle_screen_tokens.dart';
import 'package:kincircle/widgets/battery_shield_card.dart';
import 'package:kincircle/widgets/dashboard/battery_overview_card.dart';
import 'package:kincircle/widgets/dashboard/members_online_card.dart';
import 'package:kincircle/widgets/dashboard/recent_activity_card.dart';
import 'package:kincircle/widgets/dashboard/rhythm_teaser_card.dart';
import 'package:kincircle/widgets/dashboard/safe_places_card.dart';
import 'package:kincircle/widgets/dashboard/two_row_skeleton.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('1. Empty States Tests', () {
    testWidgets('recent_activity_card shows empty state when items is empty', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RecentActivityCard(items: []),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('No recent activity'), findsOneWidget);
      expect(
        find.text('Activity will appear here as your family moves and checks in'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.history_toggle_off_rounded), findsOneWidget);
    });

    testWidgets('safe_places_card shows empty state when count is 0', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SafePlacesCard(count: 0, onTap: () {}),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('No safe places yet'), findsOneWidget);
      expect(
        find.text('Add your first safe place to get alerts when family arrives or leaves'),
        findsOneWidget,
      );
    });

    testWidgets('rhythm_teaser_card shows empty state when predictions are empty', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RhythmTeaserCard(hasPredictions: false),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('No rhythm predictions yet'), findsOneWidget);
      expect(
        find.text("Check in daily to build your family's movement patterns"),
        findsOneWidget,
      );
    });

    testWidgets('members_online_card shows empty state when online members is 0', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MembersOnlineCard(onlineMembers: [], totalCount: 0),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('No one online'), findsOneWidget);
      expect(
        find.text('Family members will appear here when they open the app'),
        findsOneWidget,
      );
    });

    testWidgets('battery cards show unavailable state when battery data is missing', (tester) async {
      // BatteryOverviewCard
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BatteryOverviewCard(member: null, percent: null),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Battery data unavailable'), findsOneWidget);
      expect(
        find.text('Ensure family members have location and battery permissions enabled'),
        findsOneWidget,
      );

      // BatteryShieldCard
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BatteryShieldCard(isLoading: false, isAvailable: false),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Battery data unavailable'), findsOneWidget);
      expect(
        find.text('Ensure family members have location and battery permissions enabled'),
        findsOneWidget,
      );
    });
  });

  group('2. Loading Skeletons Tests', () {
    testWidgets('recent_activity_card renders TwoRowSkeleton when items is null', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RecentActivityCard(items: null),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(TwoRowSkeleton), findsOneWidget);
    });

    testWidgets('safe_places_card renders TwoRowSkeleton when count is null', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SafePlacesCard(count: null, onTap: () {}),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(TwoRowSkeleton), findsOneWidget);
    });

    testWidgets('rhythm_teaser_card renders TwoRowSkeleton when isLoading is true', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RhythmTeaserCard(isLoading: true),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(TwoRowSkeleton), findsOneWidget);
    });

    testWidgets('members_online_card renders TwoRowSkeleton when onlineMembers is null', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MembersOnlineCard(onlineMembers: null, totalCount: null),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(TwoRowSkeleton), findsOneWidget);
    });

    testWidgets('battery_overview_card renders TwoRowSkeleton when isLoading is true', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BatteryOverviewCard(member: null, percent: null, isLoading: true),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(TwoRowSkeleton), findsOneWidget);
    });
  });

  group('3. Tokens and Grid Unit Tests', () {
    test('KinCircleTypography includes caption10', () {
      final style = KinCircleTypography.caption10(color: Colors.white, weight: FontWeight.w700);
      expect(style.fontSize, equals(10));
      expect(style.fontWeight, equals(FontWeight.w700));
    });
  });
}
