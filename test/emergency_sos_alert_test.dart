import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kincircle/services/emergency_response_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFirebaseFirestore store;
  const String myUid = 'user-alice';
  const String myName = 'Alice';
  const String otherMember1 = 'user-bob';
  const String otherMember2 = 'user-carol';
  const String famId = 'family-test-123';

  setUp(() async {
    store = FakeFirebaseFirestore();
    EmergencyResponseService.setFirestoreForTesting(store);

    // Seed family document with 3 members
    await store.collection('families').doc(famId).set(<String, dynamic>{
      'name': 'The Kin Family',
      'ownerId': myUid,
      'members': <String>[myUid, otherMember1, otherMember2],
    });

    // Seed user doc
    await store.collection('users').doc(myUid).set(<String, dynamic>{
      'displayName': myName,
      'currentFamilyId': famId,
    });
  });

  tearDown(() {
    EmergencyResponseService.setFirestoreForTesting(null);
  });

  test(
      'triggering an emergency in a 3-member family writes exactly 2 sos alert docs',
      () async {
    final alert = EmergencyAlert(
      currentLat: 37.7749,
      currentLng: -122.4194,
      riskLevel: EmergencyRiskLevel.critical,
      riskFactors: <String>['manual_sos_button'],
    );

    await EmergencyResponseService.triggerEmergencyResponse(
      userId: myUid,
      alert: alert,
      firestore: store,
    );

    // 1. Check emergency_responses collection (audit log)
    final responseSnap = await store.collection('emergency_responses').get();
    expect(responseSnap.docs.length, equals(1));
    expect(responseSnap.docs.first.data()['userId'], equals(myUid));

    // 2. Check alerts collection - exactly 2 alert docs for the other 2 family members
    final alertsSnap = await store.collection('alerts').get();
    expect(alertsSnap.docs.length, equals(2));

    final userIds = alertsSnap.docs
        .map((doc) => doc.data()['userId'] as String)
        .toList();
    expect(userIds, containsAll(<String>[otherMember1, otherMember2]));
    expect(userIds, isNot(contains(myUid)));

    for (final doc in alertsSnap.docs) {
      final data = doc.data();
      expect(data['familyId'], equals(famId));
      expect(data['triggeredByUid'], equals(myUid));
      expect(data['triggeredByName'], equals(myName));
      expect(data['type'], equals('sos'));
      expect(data['title'], equals('SOS — Alice needs help now'));
      expect(
        data['message'],
        contains('https://maps.google.com/?q=37.7749,-122.4194'),
      );
      expect(data['seen'], isFalse);
      expect(data.containsKey('timestamp'), isTrue);
    }
  });

  test(
      'triggering an emergency with 0,0 lat/lng formats title & message cleanly',
      () async {
    final alert = EmergencyAlert(
      currentLat: 0,
      currentLng: 0,
      riskLevel: EmergencyRiskLevel.high,
      riskFactors: <String>['fall_detected'],
    );

    await EmergencyResponseService.triggerEmergencyResponse(
      userId: myUid,
      alert: alert,
      firestore: store,
    );

    final alertsSnap = await store.collection('alerts').get();
    expect(alertsSnap.docs.length, equals(2));

    for (final doc in alertsSnap.docs) {
      final data = doc.data();
      expect(data['type'], equals('sos'));
      expect(data['title'], equals('SOS — Alice needs help now'));
      expect(data['message'], equals('SOS — Alice needs help now'));
      expect(data['seen'], isFalse);
    }
  });
}