import 'sendgrid_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthMailService {
  AuthMailService({SendGridService? sendgrid, FirebaseAuth? auth})
      : _sg = sendgrid ??
            (() {
              const apiKey = String.fromEnvironment('SENDGRID_API_KEY', defaultValue: '');
              const fromEmail = String.fromEnvironment('FROM_EMAIL', defaultValue: 'no-reply@kincircle.app');
              return SendGridService(
                apiKey: apiKey,
                fromEmail: fromEmail,
                fromName: 'KinCircle',
              );
            })(),
        _auth = auth ?? FirebaseAuth.instance;

  final SendGridService _sg;
  final FirebaseAuth _auth;

  Future<void> sendWelcomeIfPossible() async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (email == null || email.isEmpty) return;
    if (!_sg.isConfigured) return;
  const html = '''
      <div style="font-family:Inter,Segoe UI,Arial,sans-serif;color:#0F172A">
        <h2 style="color:#2E86AB;margin:0 0 16px">Welcome to KinCircle</h2>
        <p>We’re glad you’re here. Set up your family and invite loved ones to get started.</p>
      </div>
    ''';
  await _sg.sendEmail(toEmail: email, subject: 'Welcome to KinCircle', html: html);
  }

  Future<void> sendPasswordReset(String toEmail, String resetLink) async {
    if (!_sg.isConfigured) return;
    final html = '''
      <div style="font-family:Inter,Segoe UI,Arial,sans-serif;color:#0F172A">
        <h2 style="color:#2E86AB;margin:0 0 16px">Reset your password</h2>
        <p>Tap the button below to reset your password.</p>
        <p style="margin:24px 0">
          <a href="$resetLink" style="background:#2E86AB;color:#fff;padding:12px 16px;border-radius:8px;text-decoration:none">Reset Password</a>
        </p>
        <p>Or open this link: <a href="$resetLink">$resetLink</a></p>
      </div>
    ''';
    await _sg.sendEmail(toEmail: toEmail, subject: 'Reset your KinCircle password', html: html);
  }
}
