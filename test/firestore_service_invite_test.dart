import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kincircle/services/firestore_service.dart';

void main() {
  group('FirestoreService.generateInviteId', () {
    test('throws when not authenticated', () async {
      final mockStore = FakeFirebaseFirestore();
      final svc = FirestoreService(
        firestore: mockStore,
        currentUidProvider: () => null,
      );
      expect(() => svc.generateInviteId(), throwsA(anything));
    });

    test('throws when user has no currentFamilyId', () async {
      final store = FakeFirebaseFirestore();
      const uid = 'u1';
      // user doc exists but no currentFamilyId
      await store.collection('users').doc(uid).set({'email': 'x@y.com'});

      final svc = FirestoreService(
        firestore: store,
        currentUidProvider: () => uid,
      );
      expect(() => svc.generateInviteId(), throwsA(isA<Exception>()));
    });

    test('returns id on success', () async {
      final store = FakeFirebaseFirestore();
      const uid = 'u1';
      await store.collection('users').doc(uid).set({'currentFamilyId': 'f1'});

      final svc = FirestoreService(
        firestore: store,
        currentUidProvider: () => uid,
      );
      final id = await svc.generateInviteId();
      expect(id, isNotEmpty);
      final created = await store.collection('invites').doc(id).get();
      expect(created.exists, true);
    });
  });
}
