import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import '../../services/auth_service.dart';
import '../../widgets/social_auth_button.dart';
import '../../widgets/primary_button.dart';
import '../../utils/theme.dart';
import '../../widgets/floaty_background.dart';

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
  Future<void> _handleAuthAction(Future<dynamic> Function() authFunction) async {
    setState(() => _isLoading = true);
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
        message = 'An unexpected error occurred.';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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
                            ? 'Log in with Google, Apple, or your email.'
                            : 'Sign up with Google, Apple, or your email.'
                        ,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 16),
                      SocialAuthButton(
                        text: 'Continue with Google',
                        icon: Icons.account_circle_outlined,
                        onPressed: _isLoading
                            ? null
                            : () => _handleAuthAction(
                                  _authService.signInWithGoogle,
                                ),
                      ),
                      const SizedBox(height: 16),
                      SocialAuthButton(
                        text: 'Continue with Apple',
                        icon: Icons.apple,
                        onPressed: _isLoading
                            ? null
                            : () => _handleAuthAction(
                                  _authService.signInWithApple,
                                ),
                      ),
                      const SizedBox(height: 20),
                      // "OR" Divider
                      Row(
                        children: [
                          const Expanded(child: Divider()),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
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
                        decoration: const InputDecoration(labelText: 'Email Address'),
                        keyboardType: TextInputType.emailAddress,
                        enabled: !_isLoading,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        decoration: const InputDecoration(labelText: 'Password'),
                        obscureText: true,
                        enabled: !_isLoading,
                      ),
                      const SizedBox(height: 20),
                      // Primary Action Button
                      _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : PrimaryButton(
                              text: _isLoginView ? 'Log In' : 'Sign Up',
                              onPressed: () {
                                final email = _emailController.text.trim();
                                final password = _passwordController.text.trim();
                                if (_isLoginView) {
                                  _handleAuthAction(() => _authService.signInWithEmail(email, password));
                                } else {
                                  _handleAuthAction(() => _authService.signUpWithEmail(email, password));
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
