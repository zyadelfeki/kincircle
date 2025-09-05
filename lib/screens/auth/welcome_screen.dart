import 'package:flutter/material.dart';
import '../../widgets/primary_button.dart';
import '../../utils/theme.dart';
import '../../widgets/floaty_background.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../utils/constants.dart';

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
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Responsive paddings and logo size based on height
                final isCompact = constraints.maxHeight < 600;
                final edge = isCompact ? 12.0 : 24.0;

                return Padding(
                  padding: EdgeInsets.all(edge),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Top hero/logo section grows but can shrink as needed
                      Flexible(
                        flex: 5,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Center(
                            child: FittedBox(
                              fit: BoxFit.contain,
                              child: SizedBox(
                                width: 360,
                                height: 360,
                                child: SvgPicture.asset(
                                  AppConstants.brandLogoAsset,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Title row
                      Flexible(
                        flex: 2,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Hero(
                                  tag: 'kc-logo',
                                  child: Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppTheme.primaryBlue
                                          .withValues(alpha: 0.10),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(6.0),
                                      child: SvgPicture.asset(
                                        AppConstants.brandLogoAsset,
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Flexible(
                                  child: Text(
                                    'Kin Arc',
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Peace of mind, powered by AI.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Stay connected and keep your loved ones safe.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Buttons and legal section pinned to bottom but responsive
                      Flexible(
                        flex: 3,
                        child: Column(
                          mainAxisSize: MainAxisSize.max,
                          children: [
                            PrimaryButton(
                              text: 'Get Started',
                              onPressed: () =>
                                  Navigator.of(context).pushNamed('/auth'),
                            ),
                            const SizedBox(height: 12),
                            TextButton(
                              onPressed: () => Navigator.of(context).pushNamed(
                                '/auth',
                                arguments: {'mode': 'login'},
                              ),
                              style: TextButton.styleFrom(
                                foregroundColor: AppTheme.primaryBlue,
                                minimumSize: const Size(44, 44),
                              ),
                              child: const Text('Log In'),
                            ),
                            const SizedBox(height: 12),
                            Flexible(
                              child: SingleChildScrollView(
                                physics: const NeverScrollableScrollPhysics(),
                                child: Text(
                                  'By continuing, you agree to our Terms of Service and Privacy Policy.',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: Colors.grey[700]),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
