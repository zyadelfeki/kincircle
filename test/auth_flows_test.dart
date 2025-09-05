import 'package:flutter_test/flutter_test.dart';
import 'package:kincircle/services/auth_service.dart';
import 'package:mockito/mockito.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

class MockUser extends Mock implements User {}

// Lightweight stub for FirebaseAuth avoiding Mockito's non-nullable return pitfalls
class StubAuth extends Fake implements FirebaseAuth {
  User? nextUser;
  Object? signUpError;

  @override
  User? get currentUser => nextUser;

  @override
  Stream<User?> authStateChanges() => Stream<User?>.value(nextUser);

  @override
  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    if (signUpError != null) {
      return Future<UserCredential>.error(signUpError!);
    }
    return FakeUserCredential(nextUser);
  }

  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    return FakeUserCredential(nextUser);
  }

  @override
  Future<void> signOut() async {
    nextUser = null;
  }
}

// Minimal concrete fake to avoid mocking nested getters
class FakeUserCredential implements UserCredential {
  FakeUserCredential(this._user);
  final User? _user;
  @override
  User? get user => _user;
  @override
  AdditionalUserInfo? get additionalUserInfo => null;
  @override
  AuthCredential? get credential => null;
}

// Test-specific AuthService that skips Firestore user doc creation
class TestAuthService extends AuthService {
  TestAuthService({required FirebaseAuth auth, required FirebaseFirestore firestore})
      : super(auth: auth, firestore: firestore, subscribeAuthChanges: false);

  @override
  Future<void> ensureUserDocument(User user) async {
    // no-op in tests
  }
}

void main() {
  group('Auth flows (email/password)', () {
    late StubAuth mockAuth;
    late FirebaseFirestore store;
    late AuthService auth;

    setUp(() {
      mockAuth = StubAuth();
      store = FakeFirebaseFirestore();
      auth = TestAuthService(auth: mockAuth, firestore: store);
    });

    test('signUpWithEmail maps Firebase errors to friendly messages', () async {
      // Arrange stub before calling subject
      mockAuth.signUpError = FirebaseAuthException(
        code: 'email-already-in-use',
        message: 'Email exists',
      );

      // Act/Assert
      await expectLater(
        auth.signUpWithEmail('a@b.com', '123456'),
        throwsA(isA<Exception>().having((e) => e.toString(), 'message contains', contains('already exists'))),
      );
    });

    test('signInWithEmail returns user on success', () async {
      final user = MockUser();
      mockAuth.nextUser = user;

      final result = await auth.signInWithEmail('a@b.com', '123456');
      expect(result, equals(user));
    });
  });
}
