import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:kincircle/services/rhythm/rhythm_store.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('hive_persistence_test_');
    Hive.init(tempDir.path);
  });

  tearDown(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('RhythmStore baseline data survives close and reopen from disk', () async {
    const String userId = 'persist_user_123';
    const String geofenceId = 'work_zone';
    final DateTime arrival = DateTime(2026, 8, 24, 8, 30); // 8:30 AM = 510 mins

    // 1. First store instance writes data to Hive
    final store1 = RhythmStore();
    await store1.init();
    await store1.recordArrival(
      userId: userId,
      geofenceId: geofenceId,
      arrivalTime: arrival,
      dayType: 'weekday',
    );

    final baseline1 = store1.getBaseline(
      userId: userId,
      geofenceId: geofenceId,
      dayType: 'weekday',
    );
    expect(baseline1, isNotNull);
    expect(baseline1!.sampleCount, equals(1));
    expect(baseline1.ewmaArrivalMinutes, equals(510.0));

    // 2. Close store 1
    await store1.close();

    // 3. Second store instance opens the same Hive box from disk
    final store2 = RhythmStore();
    await store2.init();

    final baseline2 = store2.getBaseline(
      userId: userId,
      geofenceId: geofenceId,
      dayType: 'weekday',
    );

    expect(baseline2, isNotNull);
    expect(baseline2!.userId, equals(userId));
    expect(baseline2.geofenceId, equals(geofenceId));
    expect(baseline2.sampleCount, equals(1));
    expect(baseline2.ewmaArrivalMinutes, equals(510.0));
    expect(baseline2.formattedArrival, equals('08:30'));

    await store2.close();
  });
}
