import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
// Note: Firebase is initialized in main.dart; this import provides FirebaseException type.
import 'package:google_fonts/google_fonts.dart';
import '../../services/auth_service.dart';
import '../../services/auth_mail_service.dart';
import '../../services/password_reset_service.dart';

// ignore_for_file: library_private_types_in_public_api
class LoginSignupScreen extends StatefulWidget {
  const LoginSignupScreen({super.key, this.startInLoginMode = false});

  final bool startInLoginMode;

  @override
  _LoginSignupScreenState createState() => _LoginSignupScreenState();
}

class _LoginSignupScreenState extends State<LoginSignupScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();

  static const Color _background = Color(0xFF0B0F1A);
  static const Color _surface = Color(0xFF151A28);
  static const Color _border = Color(0xFF1E2640);
  static const Color _accent = Color(0xFF00C9A7);
  static const Color _muted = Color(0xFF8A8FA8);

  bool _isLoginView = false;
  bool _isLoading = false;
  bool _argsHandled = false;
  String? _inlineError;

  Future<void> _showForgotPasswordDialog() async {
    final controller =
        TextEditingController(text: _emailController.text.trim());
    final formKey = GlobalKey<FormState>();
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    final submitted = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Reset password'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Email address',
                hintText: 'you@example.com',
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                final t = (v ?? '').trim();
                if (t.isEmpty) return 'Email is required';
                if (!emailRegex.hasMatch(t)) return 'Enter a valid email';
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() == true) {
                  Navigator.of(context).pop(true);
                }
              },
              child: const Text('Send link'),
            ),
          ],
        );
      },
    );
    if (submitted == true) {
      final email = controller.text.trim();
      await PasswordResetService().requestPasswordReset(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'If an account exists for that email, a reset link will be sent.'),
        ),
      );
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _isLoginView = widget.startInLoginMode;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argsHandled) return;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      final mode = (args['mode'] ?? args['login'])?.toString().toLowerCase();
      if (mode == 'login' || mode == 'true') {
        _isLoginView = true;
      } else if (mode == 'signup' || mode == 'false') {
        _isLoginView = false;
      }
    }
    _argsHandled = true;
  }

  // A helper function to handle auth calls, loading state, and errors
  Future<void> _handleAuthAction(
      Future<dynamic> Function() authFunction) async {
    setState(() => _isLoading = true);
    setState(() => _inlineError = null);
    try {
      await authFunction();
      // On success, reveal AuthWrapper so it can route to onboarding/permissions/dashboard.
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      // Surface helpful messages coming from AuthService (which throws Exception with details)
      String message;
      if (e is FirebaseException && e.message != null) {
        message = e.message!;
      } else {
        message = e.toString();
      }
      // Trim common prefixes
      message = message.replaceFirst(RegExp(r'^Exception:\s*'), '');
      if (message.isEmpty) {
        message =
            'We couldn’t complete that. Try these:\n• Check your internet connection.\n• If you changed phones, log in again with the same account.\n• Or use Email sign-in below.';
      }
      if (mounted) setState(() => _inlineError = message);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildSocialButton({
    required String label,
    required Widget icon,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(width: 24, height: 24, child: icon),
            ),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration({required String hintText}) {
    const radius = BorderRadius.all(Radius.circular(16));
    return InputDecoration(
      hintText: hintText,
      hintStyle: GoogleFonts.inter(
        color: _muted,
        fontSize: 16,
      ),
      filled: true,
      fillColor: _surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: const OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: _border, width: 1),
      ),
      enabledBorder: const OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: _border, width: 1),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: _accent, width: 1.4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final heading = _isLoginView ? 'Welcome back' : 'Create account';
    final subtitle = _isLoginView
        ? 'Sign in to your account.'
        : 'Sign up to create your account.';

    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 14),
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 26),
                          Text(
                            heading,
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 44,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              height: 1.05,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            subtitle,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              color: _muted,
                            ),
                          ),
                          const SizedBox(height: 28),
                          _buildSocialButton(
                            label: 'Continue with Apple',
                            icon: const Icon(Icons.apple,
                                color: Colors.black, size: 24),
                            onPressed: _isLoading
                                ? null
                                : () => _handleAuthAction(
                                      _authService.signInWithApple,
                                    ),
                          ),
                          const SizedBox(height: 12),
                          _buildSocialButton(
                            label: 'Continue with Google',
                            icon: Image.asset(
                              'assets/sq-google-g-logo-update_dezeen_2364_col_0.jpg',
                              width: 24,
                              height: 24,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Text(
                                'G',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF4285F4),
                                ),
                              ),
                            ),
                            onPressed: _isLoading
                                ? null
                                : () => _handleAuthAction(
                                      _authService.signInWithGoogle,
                                    ),
                          ),
                          const SizedBox(height: 22),
                          Row(
                            children: [
                              const Expanded(
                                child: Divider(color: _border, thickness: 1),
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                child: Text(
                                  'or',
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    color: _muted,
                                  ),
                                ),
                              ),
                              const Expanded(
                                child: Divider(color: _border, thickness: 1),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Email',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            enabled: !_isLoading,
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                            cursorColor: _accent,
                            decoration:
                                _fieldDecoration(hintText: 'Enter your email'),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Password',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _passwordController,
                            obscureText: true,
                            enabled: !_isLoading,
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                            cursorColor: _accent,
                            decoration:
                                _fieldDecoration(hintText: '••••••••••••'),
                          ),
                          if (_isLoginView) ...[
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _isLoading
                                    ? null
                                    : _showForgotPasswordDialog,
                                style: TextButton.styleFrom(
                                  foregroundColor: _accent,
                                  minimumSize: const Size(44, 36),
                                  padding: EdgeInsets.zero,
                                ),
                                child: Text(
                                  'Forgot password?',
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    color: _accent,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ],
                          if (_inlineError != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: const Color(0xFF4A1A23),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFFF6E87),
                                  width: 1,
                                ),
                              ),
                              padding: const EdgeInsets.all(12),
                              child: Text(
                                _inlineError!,
                                style: GoogleFonts.inter(
                                  color: const Color(0xFFFFB8C6),
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 22),
                          SizedBox(
                            width: double.infinity,
                            height: 58,
                            child: ElevatedButton(
                              onPressed: _isLoading
                                  ? null
                                  : () {
                                      final email =
                                          _emailController.text.trim();
                                      final password =
                                          _passwordController.text.trim();
                                      if (_isLoginView) {
                                        _handleAuthAction(() => _authService
                                            .signInWithEmail(email, password));
                                      } else {
                                        _handleAuthAction(() async {
                                          await _authService.signUpWithEmail(
                                              email, password);
                                          await AuthMailService()
                                              .sendWelcomeIfPossible();
                                        });
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _accent,
                                foregroundColor: Colors.black,
                                disabledBackgroundColor:
                                    _accent.withValues(alpha: 0.6),
                                disabledForegroundColor:
                                    Colors.black.withValues(alpha: 0.7),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.4,
                                        color: Colors.black,
                                      ),
                                    )
                                  : Text(
                                      _isLoginView ? 'Log In' : 'Sign Up',
                                      style: GoogleFonts.inter(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.black,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Center(
                            child: TextButton(
                              onPressed: _isLoading
                                  ? null
                                  : () {
                                      setState(
                                          () => _isLoginView = !_isLoginView);
                                    },
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white,
                                minimumSize: const Size(44, 40),
                              ),
                              child: RichText(
                                text: TextSpan(
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    color: Colors.white,
                                  ),
                                  children: _isLoginView
                                      ? const [
                                          TextSpan(
                                              text: "Don't have an account? "),
                                          TextSpan(
                                            text: 'Sign Up',
                                            style: TextStyle(
                                              color: _accent,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ]
                                      : const [
                                          TextSpan(
                                              text:
                                                  'Already have an account? '),
                                          TextSpan(
                                            text: 'Log In',
                                            style: TextStyle(
                                              color: _accent,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Text(
                    'By continuing, you agree to our Terms of Service and Privacy Policy.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: _muted,
                    ),
                  ),
                  const SizedBox(height: 2),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
