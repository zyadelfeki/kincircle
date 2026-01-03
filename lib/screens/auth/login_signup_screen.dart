import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
// Note: Firebase is initialized in main.dart; this import provides FirebaseException type.
import '../../services/auth_service.dart';
import '../../widgets/social_auth_button.dart';
import '../../widgets/primary_button.dart';
import '../../utils/theme.dart';
import '../../widgets/floaty_background.dart';
import '../../services/auth_mail_service.dart';
import '../../services/password_reset_service.dart';

// ignore_for_file: library_private_types_in_public_api
class LoginSignupScreen extends StatefulWidget {
  const LoginSignupScreen({super.key});

  @override
  _LoginSignupScreenState createState() => _LoginSignupScreenState();
}

class _LoginSignupScreenState extends State<LoginSignupScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();

  bool _isLoginView = false;
  bool _isLoading = false;
  bool _argsHandled = false;
  String? _inlineError;

  Future<void> _showForgotPasswordDialog() async {
    final controller = TextEditingController(text: _emailController.text.trim());
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argsHandled) return;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      final mode = (args['mode'] ?? args['login'])?.toString().toLowerCase();
      if (mode == 'login' || mode == 'true') {
        _isLoginView = true;
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

  Widget _buildCircularSocialButton({
    required VoidCallback? onPressed,
    required Widget child,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          border: Border.all(color: Colors.grey.shade300),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isLoginView ? 'Log In' : 'Sign Up'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Help',
            icon: const Icon(Icons.help_outline),
            onPressed: () => Navigator.of(context).pushNamed('/help'),
          ),
        ],
      ),
      body: Stack(
        children: [
          const FloatyBackground(),
          SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.95, end: 1.0),
              duration: const Duration(milliseconds: 300),
              builder: (context, value, child) => Transform.scale(
                scale: value,
                child: child,
              ),
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Compact header to avoid logo duplication and keep focus on actions
                      Text(
                        _isLoginView ? 'Welcome back' : 'Create your account',
                        style: Theme.of(context).textTheme.titleLarge,
                        textAlign: TextAlign.left,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isLoginView
                            ? 'Log in with your social account or email.'
                            : 'Sign up with your social account or email.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (_inlineError != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: Colors.red.withValues(alpha: 0.2)),
                          ),
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.info_outline,
                                  color: Colors.red, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _inlineError!,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: Colors.red.shade700),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      // Social Login Buttons - Circular Design
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Google Button
                          _buildCircularSocialButton(
                            onPressed: _isLoading
                                ? null
                                : () => _handleAuthAction(
                                      _authService.signInWithGoogle,
                                    ),
                            child: ClipOval(
                              child: Image.asset(
                                'assets/sq-google-g-logo-update_dezeen_2364_col_0.jpg',
                                width: 32,
                                height: 32,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Text('G', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF4285F4))),
                              ),
                            ),
                          ),
                          const SizedBox(width: 24),
                          // Apple Button
                          _buildCircularSocialButton(
                            onPressed: _isLoading
                                ? null
                                : () => _handleAuthAction(
                                      _authService.signInWithApple,
                                    ),
                            child: const Icon(Icons.apple, size: 28, color: Colors.black87),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // "OR" Divider
                      Row(
                        children: [
                          const Expanded(child: Divider()),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16.0),
                            child: Text(
                              'or',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                          const Expanded(child: Divider()),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // Email/Password Fields
                      TextFormField(
                        controller: _emailController,
                        decoration:
                            const InputDecoration(labelText: 'Email Address'),
                        keyboardType: TextInputType.emailAddress,
                        enabled: !_isLoading,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        decoration:
                            const InputDecoration(labelText: 'Password'),
                        obscureText: true,
                        enabled: !_isLoading,
                      ),
                      if (_isLoginView) ...[
                        const SizedBox(height: 4),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _isLoading ? null : _showForgotPasswordDialog,
                            child: const Text('Forgot password?'),
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      // Primary Action Button
                      _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : PrimaryButton(
                              text: _isLoginView ? 'Log In' : 'Sign Up',
                              onPressed: () {
                                final email = _emailController.text.trim();
                                final password =
                                    _passwordController.text.trim();
                                if (_isLoginView) {
                                  _handleAuthAction(() => _authService
                                      .signInWithEmail(email, password));
                                } else {
                                  _handleAuthAction(() async {
                                    await _authService
                                        .signUpWithEmail(email, password);
                                    // Fire branded Welcome email when possible
                                    await AuthMailService()
                                        .sendWelcomeIfPossible();
                                  });
                                }
                              },
                            ),
                      const SizedBox(height: 8),
                      // Toggle between Login and Sign Up
                      TextButton(
                        onPressed: _isLoading
                            ? null
                            : () {
                                setState(() => _isLoginView = !_isLoginView);
                              },
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.primaryBlue,
                          minimumSize: const Size(44, 44),
                        ),
                        child: Text(
                          _isLoginView
                              ? "Don't have an account? Sign Up"
                              : 'Already have an account? Log In',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
