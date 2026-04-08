import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:flutter/foundation.dart';
import '../utils/constants.dart';

class AuthService extends ChangeNotifier {
  AuthService(
      {FirebaseAuth? auth,
      FirebaseFirestore? firestore,
      Future<void> Function()? authSignOutOverride,
      bool subscribeAuthChanges = true})
      : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _authSignOutOverride = authSignOutOverride {
    _user = _auth.currentUser;
    if (subscribeAuthChanges) {
      _auth.authStateChanges().listen((u) {
        _user = u;
        notifyListeners();
      });
    }
  }

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  bool _isLoading = false;
  final Future<void> Function()? _authSignOutOverride;
  User? _user;

  // Current user and stream (for legacy listeners)
  User? get user => _user;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Expose loading state
  bool get isLoading => _isLoading;

  // Map FirebaseAuthException to user-friendly messages with guidance
  String _friendlyAuthMessage(FirebaseAuthException e,
      {required bool isSignUp}) {
    final code = e.code.toLowerCase();
    final msg = (e.message ?? '').toLowerCase();
    switch (code) {
      case 'invalid-email':
        return 'That email looks invalid. Please check and try again.';
      case 'user-not-found':
        return 'No account found for that email. Try signing up.';
      case 'wrong-password':
        return 'Incorrect password. Please try again or reset it.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a bit and try again.';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled. Please contact support.';
      case 'email-already-in-use':
        return 'An account already exists for that email. Try logging in instead.';
      case 'weak-password':
        return 'That password is too weak. Use at least 6 characters.';
      case 'network-request-failed':
        return AppConstants.networkError;
      case 'invalid-credential':
        // Common on Android when Play Integrity/Recaptcha token is missing or SHA keys are not configured
        if (msg.contains('recaptcha') ||
            msg.contains('integrity') ||
            msg.contains('token')) {
          return ('Sign ${isSignUp ? 'up' : 'in'} blocked: Android device verification failed.\n'
              '- Add your Android SHA-1 and SHA-256 to Firebase Console > Project settings > Your app (com.zyad.kincircle).\n'
              '- Download a fresh google-services.json into android/app.\n'
              '- Uninstall the app, then rebuild and try again.');
        }
        return 'Authentication failed. Please verify your credentials and try again.';
      default:
        return '${AppConstants.authError} ${e.message ?? ''}'.trim();
    }
  }

  // --- Ensure user document exists in Firestore ---
  Future<void> ensureUserDocument(User user) async {
    final userDoc =
        _firestore.collection(AppConstants.usersCollection).doc(user.uid);
    final docSnapshot = await userDoc.get();
    final String email = (user.email ?? '').trim();
    final String displayName = (user.displayName ?? '').trim().isNotEmpty
        ? user.displayName!.trim()
        : (email.contains('@') ? email.split('@').first.trim() : 'Unknown');

    if (!docSnapshot.exists) {
      await userDoc.set({
        AppConstants.userUid: user.uid,
        AppConstants.userEmail: user.email,
        AppConstants.userDisplayName: displayName,
        AppConstants.userPhotoUrl: user.photoURL ?? '',
        AppConstants.userCreatedAt: FieldValue.serverTimestamp(),
        'onboardingComplete': false,
        AppConstants.userSetupComplete: false,
      });
      return;
    }

    final Map<String, dynamic>? existing = docSnapshot.data();
    final String existingName =
        (existing?[AppConstants.userDisplayName] ?? '').toString().trim();
    if (existingName.isEmpty) {
      await userDoc.update(<String, dynamic>{
        AppConstants.userDisplayName: displayName,
      });
    }
  }

  // --- SIGN IN WITH GOOGLE ---
  Future<User?> signInWithGoogle() async {
    try {
      _isLoading = true;
      // Use FirebaseAuth's provider-based sign-in (works across platforms)
      final googleProvider = GoogleAuthProvider();
      final UserCredential userCredential =
          await _auth.signInWithProvider(googleProvider);
      await ensureUserDocument(userCredential.user!);
      _user = userCredential.user;
      notifyListeners();
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      throw Exception(_friendlyAuthMessage(e, isSignUp: false));
    } catch (e) {
      throw Exception('${AppConstants.genericError}: $e');
    } finally {
      _isLoading = false;
    }
  }

  // --- SIGN IN WITH APPLE ---
  Future<User?> signInWithApple() async {
    try {
      _isLoading = true;
      final AuthorizationCredentialAppleID appleCredential =
          await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
      final OAuthProvider oAuthProvider = OAuthProvider('apple.com');
      final OAuthCredential credential = oAuthProvider.credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );
      final UserCredential userCredential =
          await _auth.signInWithCredential(credential);
      await ensureUserDocument(userCredential.user!);
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      throw Exception(_friendlyAuthMessage(e, isSignUp: false));
    } catch (e) {
      throw Exception('${AppConstants.genericError}: $e');
    } finally {
      _isLoading = false;
    }
  }

  // --- SIGN UP WITH EMAIL & PASSWORD ---
  Future<User?> signUpWithEmail(String email, String password) async {
    try {
      _isLoading = true;
      final UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await ensureUserDocument(userCredential.user!);
      _user = userCredential.user;
      notifyListeners();
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      final msg = e.message ?? '';
      if (msg.contains('CONFIGURATION_NOT_FOUND')) {
        throw Exception(
            'Sign up blocked: Play Integrity/Recaptcha configuration not found for this app.\n'
            '- Add your Android SHA-1 and SHA-256 to Firebase Console > Project settings > Android app (com.zyad.kincircle).\n'
            '- Download the updated google-services.json and replace android/app/google-services.json.\n'
            '- Uninstall the app from the emulator/device, then rebuild and run.');
      }
      throw Exception(_friendlyAuthMessage(e, isSignUp: true));
    } catch (e) {
      throw Exception('${AppConstants.genericError}: $e');
    } finally {
      _isLoading = false;
    }
  }

  // --- SIGN IN WITH EMAIL & PASSWORD ---
  Future<User?> signInWithEmail(String email, String password) async {
    try {
      _isLoading = true;
      final UserCredential userCredential =
          await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      await ensureUserDocument(userCredential.user!);
      _user = userCredential.user;
      notifyListeners();
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      final msg = e.message ?? '';
      if (msg.contains('CONFIGURATION_NOT_FOUND')) {
        throw Exception(
            'Sign in blocked: Play Integrity/Recaptcha configuration not found for this app.\n'
            '- Add your Android SHA-1 and SHA-256 to Firebase Console > Project settings > Android app (com.zyad.kincircle).\n'
            '- Download the updated google-services.json and replace android/app/google-services.json.\n'
            '- Uninstall the app from the emulator/device, then rebuild and run.');
      }
      throw Exception(_friendlyAuthMessage(e, isSignUp: false));
    } catch (e) {
      throw Exception('${AppConstants.genericError}: $e');
    } finally {
      _isLoading = false;
    }
  }

  // --- SIGN OUT ---
  Future<void> signOut() async {
    try {
      _isLoading = true;
      if (_authSignOutOverride != null) {
        await _authSignOutOverride!.call();
      } else {
        await _auth.signOut();
      }
      _user = null;
      notifyListeners();
    } catch (e) {
      throw Exception('${AppConstants.genericError}: $e');
    } finally {
      _isLoading = false;
    }
  }
}
