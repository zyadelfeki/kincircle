import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mockito/mockito.dart';
import 'package:kincircle/services/firestore_service.dart';

class MockFirebaseAuth extends Mock implements FirebaseAuth {}
class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}
class MockUser extends Mock implements User {}

void main() {
  group('FirestoreService', () {
    test('updateVisibility throws when not authenticated', () async {
      final mockAuth = MockFirebaseAuth();
      final mockStore = MockFirebaseFirestore();
      when(mockAuth.currentUser).thenReturn(null);

      final svc = FirestoreService(auth: mockAuth, firestore: mockStore);

      expect(
        () => svc.updateVisibility(isInvisible: true),
        throwsA(isA<Exception>()),
      );
    });

    test('sendInvite throws when not authenticated', () async {
      final mockAuth = MockFirebaseAuth();
      final mockStore = MockFirebaseFirestore();
      when(mockAuth.currentUser).thenReturn(null);

      final svc = FirestoreService(auth: mockAuth, firestore: mockStore);

      expect(
        () => svc.sendInvite(email: 'test@example.com'),
        throwsA(isA<Exception>()),
      );
    });
  });
}
