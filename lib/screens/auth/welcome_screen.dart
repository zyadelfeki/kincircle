import 'package:flutter/material.dart';
import '../../widgets/primary_button.dart';
import '../../utils/theme.dart';
import '../../widgets/floaty_background.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
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
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Hero card (image only, no overlayed texts)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: AspectRatio(
                      aspectRatio: 1024 / 500,
                      child: Image.asset(
                        'assets/marketing/feature_graphic_1024x500_v2.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Logo + name
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Hero(
                        tag: 'kc-logo',
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.primaryBlue.withValues(alpha: 0.10),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(6.0),
                            child: Image.asset('assets/icon/kincircle_icon_1024.png', fit: BoxFit.contain),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text('KinCircle', style: Theme.of(context).textTheme.headlineSmall),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Peace of mind, powered by AI.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Stay connected and keep your loved ones safe.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const Spacer(),
                  // Action Buttons
                  PrimaryButton(
                    text: 'Get Started',
                    onPressed: () {
                      Navigator.of(context).pushNamed('/auth');
                    },
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pushNamed('/auth', arguments: {'mode': 'login'});
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.primaryBlue,
                      minimumSize: const Size(44, 44),
                    ),
                    child: const Text('Log In'),
                  ),
                  TextButton.icon(
                    onPressed: () => Navigator.of(context).pushNamed('/permissions'),
                    icon: const Icon(Icons.tune),
                    label: const Text('Review Permissions'),
                  ),
                  const SizedBox(height: 24),
                  // Legal Text
                  Text(
                    'By continuing, you agree to our Terms of Service and Privacy Policy.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.grey[700]),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
} 