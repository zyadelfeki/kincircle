import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:kincircle/services/geofence_monitor_service.dart';

Position createPosition({
  required double latitude,
  required double longitude,
  DateTime? timestamp,
}) {
  return Position(
    latitude: latitude,
    longitude: longitude,
    timestamp: timestamp ?? DateTime.now(),
    accuracy: 5.0,
    altitude: 0.0,
    altitudeAccuracy: 0.0,
    heading: 0.0,
    headingAccuracy: 0.0,
    speed: 0.0,
    speedAccuracy: 0.0,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFirebaseFirestore store;
  const myUid = 'user-me';
  const myName = 'Alice';
  const otherMember1 = 'user-bob';
  const otherMember2 = 'user-carol';
  const famId = 'fam-123';

  const homeGeofence = GeofenceTarget(
    id: 'geo-home',
    name: 'Home',
    familyId: famId,
    latitude: 30.0444,
    longitude: 31.2357,
    radius: 200.0,
  );

  setUp(() async {
    store = FakeFirebaseFirestore();

    // Seed family doc with 3 members
    await store.collection('families').doc(famId).set({
      'name': 'Wonder Family',
      'ownerId': myUid,
      'members': [myUid, otherMember1, otherMember2],
    });

    // Seed user doc
    await store.collection('users').doc(myUid).set({
      'displayName': myName,
      'currentFamilyId': famId,
    });
  });

  test('stationary inside = no alert', () async {
    final monitor = GeofenceMonitorService(
      firestore: store,
      currentUidProvider: () => myUid,
      currentDisplayNameProvider: () => myName,
    );
    monitor.setGeofencesForTesting([homeGeofence]);

    final pInside = createPosition(latitude: 30.0444, longitude: 31.2357);

    // Initial reading establishes inside state baseline
    await monitor.processPosition(pInside);
    // Stationary inside
    await monitor.processPosition(pInside);
    await monitor.processPosition(pInside);

    final alertsSnap = await store.collection('alerts').get();
    expect(alertsSnap.docs, isEmpty);
  });

  test('outside -> inside = exactly one alert per other member', () async {
    final monitor = GeofenceMonitorService(
      firestore: store,
      currentUidProvider: () => myUid,
      currentDisplayNameProvider: () => myName,
    );
    monitor.setGeofencesForTesting([homeGeofence]);

    final pOutside = createPosition(latitude: 30.0600, longitude: 31.2357);
    final pInside = createPosition(latitude: 30.0444, longitude: 31.2357);

    // Baseline: outside
    await monitor.processPosition(pOutside);
    await monitor.processPosition(pOutside);

    var alertsSnap = await store.collection('alerts').get();
    expect(alertsSnap.docs, isEmpty);

    // 1st inside reading (anti-jitter requires 2 consecutive)
    await monitor.processPosition(pInside);
    alertsSnap = await store.collection('alerts').get();
    expect(alertsSnap.docs, isEmpty);

    // 2nd inside reading: fires arrival alert
    await monitor.processPosition(pInside);
    alertsSnap = await store.collection('alerts').get();

    // Exactly one alert per other member (2 other members)
    expect(alertsSnap.docs.length, equals(2));

    final userIds =
        alertsSnap.docs.map((d) => d.data()['userId'] as String).toList();
    expect(userIds, containsAll([otherMember1, otherMember2]));
    expect(userIds, isNot(contains(myUid)));

    for (final doc in alertsSnap.docs) {
      final data = doc.data();
      expect(data['familyId'], equals(famId));
      expect(data['triggeredByUid'], equals(myUid));
      expect(data['triggeredByName'], equals(myName));
      expect(data['title'], equals('Alice arrived at Home'));
      expect(data['message'], equals('Alice arrived at Home'));
      expect(data['type'], equals('geofence'));
      expect(data['seen'], isFalse);
    }
  });

  test('two readings 3 seconds apart across the boundary = no duplicate alert',
      () async {
    final monitor = GeofenceMonitorService(
      firestore: store,
      currentUidProvider: () => myUid,
      currentDisplayNameProvider: () => myName,
    );
    monitor.setGeofencesForTesting([homeGeofence]);

    final t0 = DateTime(2026, 1, 1, 12, 0, 0);
    final pOutside = createPosition(latitude: 30.0600, longitude: 31.2357);
    final pInside = createPosition(latitude: 30.0444, longitude: 31.2357);

    // Establish outside state
    await monitor.processPosition(pOutside, now: t0);
    await monitor.processPosition(pOutside,
        now: t0.add(const Duration(seconds: 1)));

    // Transition inside at t = 3s (2 consecutive readings)
    await monitor.processPosition(pInside,
        now: t0.add(const Duration(seconds: 2)));
    await monitor.processPosition(pInside,
        now: t0.add(const Duration(seconds: 3)));

    var alertsSnap = await store.collection('alerts').get();
    expect(alertsSnap.docs.length, equals(2));

    // Rapid reverse transition to outside 3 seconds later at t = 6s
    await monitor.processPosition(pOutside,
        now: t0.add(const Duration(seconds: 5)));
    await monitor.processPosition(pOutside,
        now: t0.add(const Duration(seconds: 6)));

    // Minimum 60-second cooldown prevents duplicate/rapid exit alert
    alertsSnap = await store.collection('alerts').get();
    expect(alertsSnap.docs.length, equals(2));
  });
}
