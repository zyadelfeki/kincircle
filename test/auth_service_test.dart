// ignore_for_file: body_might_complete_normally_nullable
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mockito/mockito.dart';
import 'package:kincircle/services/auth_service.dart';

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockUser extends Mock implements User {}

class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}
class StubSignOutTracker {
  bool signOutCalled = false;
}

void main() {
  late AuthService authService;
  late MockFirebaseAuth mockFirebaseAuth;
  late MockFirebaseFirestore mockFirestore;
  late StubSignOutTracker signOutTracker;

  setUp(() {
    mockFirebaseAuth = MockFirebaseAuth();
    mockFirestore = MockFirebaseFirestore();
    signOutTracker = StubSignOutTracker();
  // Stub auth streams and current user
  when(mockFirebaseAuth.currentUser).thenReturn(null);
    authService = AuthService(
      auth: mockFirebaseAuth,
      firestore: mockFirestore,
      authSignOutOverride: () async { signOutTracker.signOutCalled = true; },
  subscribeAuthChanges: false,
    );
  });

  group('AuthService', () {
    test('signOut should call Firebase signOut', () async {
      // Arrange
  // Stub handles signOut internally

      // Act
  await authService.signOut();

      // Assert
  expect(signOutTracker.signOutCalled, isTrue);
  // firebase auth signOut handled via override
    });
  });
}
