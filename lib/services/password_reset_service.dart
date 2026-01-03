import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'auth_mail_service.dart';

class PasswordResetService {
  PasswordResetService({
    FirebaseAuth? auth,
    FirebaseFunctions? functions,
    AuthMailService? mail,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _functions = functions ?? FirebaseFunctions.instance,
        _mail = mail ?? AuthMailService();

  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;
  final AuthMailService _mail;

  Future<void> requestPasswordReset(String email) async {
    final trimmed = email.trim();
    if (trimmed.isEmpty) return;

    String resetLink = '';
    try {
      final callable = _functions.httpsCallable('generatePasswordResetLink');
      final res = await callable.call({'email': trimmed});
      resetLink = (res.data is Map && res.data['resetLink'] is String)
          ? (res.data['resetLink'] as String)
          : '';
    } catch (_) {
      // ignore and fallback
    }

    if (resetLink.isNotEmpty) {
      // Prefer branded email via SendGrid if configured
      await _mail.sendPasswordReset(trimmed, resetLink);
      return;
    }

    // Fallback to Firebase default email
    try {
      await _auth.sendPasswordResetEmail(email: trimmed);
    } catch (_) {
      // Suppress details to avoid user enumeration side-channel
    }
  }
}
