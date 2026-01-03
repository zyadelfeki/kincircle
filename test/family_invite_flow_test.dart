import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kincircle/services/firestore_service.dart';

void main() {
  test('Create invite ID then accept invite adds member', () async {
    final store = FakeFirebaseFirestore();
    const owner = 'owner-uid';
    const joiner = 'joiner-uid';

    // Seed: owner user with a family
    final famRef = await store.collection('families').add({
      'name': 'Fam',
      'members': [owner],
      'ownerId': owner,
    });
    await store.collection('users').doc(owner).set({
      'currentFamilyId': famRef.id,
      'email': 'owner@example.com',
    });
    await store.collection('users').doc(joiner).set({
      'email': 'joiner@example.com',
    });

    // Owner generates invite
    final ownerSvc = FirestoreService(
      firestore: store,
      currentUidProvider: () => owner,
    );
    final inviteId = await ownerSvc.generateInviteId();
    expect(inviteId, isNotEmpty);

    // Joiner accepts invite
    final joinerSvc = FirestoreService(
      firestore: store,
      currentUidProvider: () => joiner,
    );
    await joinerSvc.acceptInvite(inviteId: inviteId);

    final famSnap = await store.collection('families').doc(famRef.id).get();
    final members = List<String>.from(famSnap.data()!['members']);
    expect(members.contains(joiner), isTrue);

    final joinerDoc = await store.collection('users').doc(joiner).get();
    expect(joinerDoc.data()!['currentFamilyId'], equals(famRef.id));
  });
}
