import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:kincircle/services/geofence_monitor_service.dart';
import 'package:kincircle/services/rhythm/rhythm_service.dart';
import 'package:kincircle/services/rhythm/rhythm_store.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('hive_rhythm_test_');
    Hive.init(tempDir.path);
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('RhythmStore EWMA calculations', () {
    late RhythmStore store;

    setUp(() async {
      store = RhythmStore();
      await store.init();
      await store.clear();
    });

    test('(a) 5 arrivals at 15:00 -> EWMA converges to 15:00, sampleCount == 5',
        () async {
      // 15:00 is 15 * 60 = 900 minutes since midnight.
      final DateTime monday1500 = DateTime(2026, 8, 24, 15, 0, 0); // Monday
      const String userId = 'user_1';
      const String geofenceId = 'home';

      for (int i = 0; i < 5; i++) {
        await store.recordArrival(
          userId: userId,
          geofenceId: geofenceId,
          arrivalTime: monday1500.add(Duration(days: i)),
        );
      }

      final baseline = store.getBaseline(
        userId: userId,
        geofenceId: geofenceId,
        dayType: 'weekday',
      );

      expect(baseline, isNotNull);
      expect(baseline!.sampleCount, equals(5));
      expect(baseline.ewmaArrivalMinutes, closeTo(900.0, 0.001));
      expect(baseline.formattedArrival, equals('15:00'));
      expect(baseline.standardDeviation, closeTo(0.0, 0.001));
    });

    test('Learns distinct weekday vs weekend patterns', () async {
      const String userId = 'user_1';
      const String geofenceId = 'gym';

      // Weekday at 08:00 (480 mins)
      final DateTime weekday = DateTime(2026, 8, 24, 8, 0);
      await store.recordArrival(
        userId: userId,
        geofenceId: geofenceId,
        arrivalTime: weekday,
      );

      // Weekend at 11:00 (660 mins)
      final DateTime weekend = DateTime(2026, 8, 29, 11, 0);
      await store.recordArrival(
        userId: userId,
        geofenceId: geofenceId,
        arrivalTime: weekend,
      );

      final wdBaseline = store.getBaseline(
        userId: userId,
        geofenceId: geofenceId,
        dayType: 'weekday',
      );
      final weBaseline = store.getBaseline(
        userId: userId,
        geofenceId: geofenceId,
        dayType: 'weekend',
      );

      expect(wdBaseline?.ewmaArrivalMinutes, equals(480.0));
      expect(weBaseline?.ewmaArrivalMinutes, equals(660.0));
    });
  });

  group('RhythmService Pattern-Break Anomaly Detection', () {
    late RhythmStore store;
    late StreamController<GeofenceTransitionEvent> transitionController;

    setUp(() async {
      store = RhythmStore();
      await store.init();
      await store.clear();
      transitionController =
          StreamController<GeofenceTransitionEvent>.broadcast();
    });

    tearDown(() async {
      await transitionController.close();
    });

    const testGeofence = GeofenceTarget(
      id: 'place_home',
      name: 'Home',
      familyId: 'fam_123',
      latitude: 37.7749,
      longitude: -122.4194,
      radius: 100,
    );

    test(
        '(b) 4 arrivals -> evaluatePatternBreaks at 17:00 returns NO anomaly (sampleCount < 5)',
        () async {
      const String uid = 'test_uid';
      final service = RhythmService(
        rhythmStore: store,
        transitionStreamOverride: transitionController.stream,
        currentUidProvider: () => uid,
        currentDisplayNameProvider: () => 'Alice',
      );

      // 4 weekday arrivals at 15:00 (900 min)
      for (int i = 0; i < 4; i++) {
        await store.recordArrival(
          userId: uid,
          geofenceId: testGeofence.id,
          arrivalTime: DateTime(2026, 8, 24 + i, 15, 0),
        );
      }

      // Check at 17:00 (1020 min, well past 15:00) on Friday (weekday)
      final DateTime evaluationTime = DateTime(2026, 8, 28, 17, 0);
      final triggered = await service.evaluatePatternBreaks(
        evaluationTime: evaluationTime,
        geofencesOverride: [testGeofence],
        isInsideGeofenceOverride: (id) => false,
      );

      expect(triggered, isEmpty);
    });

    test(
        '(c) 5 arrivals at 15:00 with tight variance -> evaluatePatternBreaks at 15:35 returns anomaly',
        () async {
      const String uid = 'test_uid';
      final service = RhythmService(
        rhythmStore: store,
        transitionStreamOverride: transitionController.stream,
        currentUidProvider: () => uid,
        currentDisplayNameProvider: () => 'Alice',
        isProProvider: () => false,
      );

      // 5 weekday arrivals at 15:00 (900 min)
      for (int i = 0; i < 5; i++) {
        await store.recordArrival(
          userId: uid,
          geofenceId: testGeofence.id,
          arrivalTime: DateTime(2026, 8, 24 + i, 15, 0),
        );
      }

      // At 15:35 (935 min > 900 + 30 min cutoff) on Friday
      final DateTime evalTime = DateTime(2026, 8, 28, 15, 35);
      final triggered = await service.evaluatePatternBreaks(
        evaluationTime: evalTime,
        geofencesOverride: [testGeofence],
        isInsideGeofenceOverride: (id) => false,
      );

      expect(triggered.length, equals(1));
      expect(triggered.first.geofenceId, equals(testGeofence.id));
      expect(triggered.first.formattedArrival, equals('15:00'));
    });

    test('(d) evaluatePatternBreaks inside the geofence at 16:00 -> NO anomaly',
        () async {
      const String uid = 'test_uid';
      final service = RhythmService(
        rhythmStore: store,
        transitionStreamOverride: transitionController.stream,
        currentUidProvider: () => uid,
        currentDisplayNameProvider: () => 'Alice',
        isProProvider: () => false,
      );

      // 5 arrivals at 15:00
      for (int i = 0; i < 5; i++) {
        await store.recordArrival(
          userId: uid,
          geofenceId: testGeofence.id,
          arrivalTime: DateTime(2026, 8, 24 + i, 15, 0),
        );
      }

      // Check at 16:00, but user IS INSIDE the geofence
      final DateTime evalTime = DateTime(2026, 8, 28, 16, 0);
      final triggered = await service.evaluatePatternBreaks(
        evaluationTime: evalTime,
        geofencesOverride: [testGeofence],
        isInsideGeofenceOverride: (id) => true, // inside!
      );

      expect(triggered, isEmpty);
    });

    test(
        '(e) Anomaly fires once -> second evaluatePatternBreaks on same day does NOT fire duplicate',
        () async {
      const String uid = 'test_uid';
      final service = RhythmService(
        rhythmStore: store,
        transitionStreamOverride: transitionController.stream,
        currentUidProvider: () => uid,
        currentDisplayNameProvider: () => 'Alice',
        isProProvider: () => false,
      );

      for (int i = 0; i < 5; i++) {
        await store.recordArrival(
          userId: uid,
          geofenceId: testGeofence.id,
          arrivalTime: DateTime(2026, 8, 24 + i, 15, 0),
        );
      }

      // First evaluation at 15:40 -> fires anomaly
      final DateTime firstCheck = DateTime(2026, 8, 28, 15, 40);
      final firstResults = await service.evaluatePatternBreaks(
        evaluationTime: firstCheck,
        geofencesOverride: [testGeofence],
        isInsideGeofenceOverride: (id) => false,
      );
      expect(firstResults.length, equals(1));

      // Second evaluation at 16:15 on the SAME DAY -> skipped due to daily cooldown
      final DateTime secondCheck = DateTime(2026, 8, 28, 16, 15);
      final secondResults = await service.evaluatePatternBreaks(
        evaluationTime: secondCheck,
        geofencesOverride: [testGeofence],
        isInsideGeofenceOverride: (id) => false,
      );
      expect(secondResults, isEmpty);

      // Third evaluation on the NEXT DAY at 15:40 -> fires again
      final DateTime nextDayCheck = DateTime(2026, 8, 29, 15, 40);
      // Train 5 weekend arrivals as well
      for (int i = 0; i < 5; i++) {
        await store.recordArrival(
          userId: uid,
          geofenceId: testGeofence.id,
          arrivalTime: DateTime(2026, 8, 22, 15, 0),
          dayType: 'weekend',
        );
      }

      final nextDayResults = await service.evaluatePatternBreaks(
        evaluationTime: nextDayCheck,
        geofencesOverride: [testGeofence],
        isInsideGeofenceOverride: (id) => false,
      );
      expect(nextDayResults.length, equals(1));
    });

    test(
        '(f) Free user pattern break -> NO alert docs written; Pro user -> invokes hook',
        () async {
      const String uid = 'test_uid';
      bool hookInvoked = false;

      final service = RhythmService(
        rhythmStore: store,
        transitionStreamOverride: transitionController.stream,
        currentUidProvider: () => uid,
        currentDisplayNameProvider: () => 'Alice',
        isProProvider: () => false, // Free user
        onPatternBreak: (geofence, baseline, timestamp) async {
          hookInvoked = true;
        },
      );

      for (int i = 0; i < 5; i++) {
        await store.recordArrival(
          userId: uid,
          geofenceId: testGeofence.id,
          arrivalTime: DateTime(2026, 8, 24 + i, 15, 0),
        );
      }

      final evalTime = DateTime(2026, 8, 28, 15, 45);
      final triggered = await service.evaluatePatternBreaks(
        evaluationTime: evalTime,
        geofencesOverride: [testGeofence],
        isInsideGeofenceOverride: (id) => false,
      );

      expect(triggered.length, equals(1));
      expect(hookInvoked, isTrue);
    });
  });
}
