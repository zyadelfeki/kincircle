import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/onboarding_prefs.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../utils/constants.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.userId});
  final String userId;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _index = 0;
  bool _saving = false;

  final _pages = const [
    (
      image: AppConstants.brandLogoAsset,
      title: 'Together is safer',
      body:
          'Create a private circle for your family so everyone can be in the loop.'
    ),
    (
      image: AppConstants.brandLogoAsset,
      title: 'See what matters',
      body: 'A calm map and timely alerts—no clutter, just peace of mind.'
    ),
    (
      image: AppConstants.brandLogoAsset,
      title: 'You’re in control',
      body: 'You choose what to share and when. Change settings anytime.'
    ),
  ];

  Future<void> _complete() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .set({'userSetupComplete': true}, SetOptions(merge: true));
      await OnboardingPrefs().setSeenWelcomeTour(true);
    } catch (_) {}
    if (!mounted) return;
    // After onboarding, guide users to enable core permissions.
    Navigator.of(context).pushReplacementNamed('/permissions');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            LinearProgressIndicator(
              value: (_index + 1) / _pages.length,
              minHeight: 2,
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) {
                  final p = _pages[i];
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final maxH = constraints.maxHeight;
                      final imageH = (maxH * 0.42).clamp(160, 320);
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(p.title,
                                style: theme.textTheme.headlineSmall,
                                textAlign: TextAlign.center),
                            const SizedBox(height: 8),
                            Text(
                              p.body,
                              style: theme.textTheme.bodyLarge
                                  ?.copyWith(color: theme.hintColor),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: SizedBox(
                                height: imageH.toDouble(),
                                width: double.infinity,
                                child: SvgPicture.asset(
                                  p.image,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(_pages.length, (dot) {
                                final active = dot == _index;
                                return AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  margin:
                                      const EdgeInsets.symmetric(horizontal: 4),
                                  height: 8,
                                  width: active ? 20 : 8,
                                  decoration: BoxDecoration(
                                    color: active
                                        ? theme.colorScheme.primary
                                        : theme.dividerColor,
                                    borderRadius: BorderRadius.circular(99),
                                  ),
                                );
                              }),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                if (_index < _pages.length - 1)
                                  TextButton(
                                    onPressed: _saving ? null : _complete,
                                    child: const Text('Skip'),
                                  )
                                else
                                  const SizedBox(width: 88),
                                const Spacer(),
                                FilledButton.icon(
                                  onPressed: _saving
                                      ? null
                                      : () {
                                          if (_index == _pages.length - 1) {
                                            _complete();
                                          } else {
                                            _controller.nextPage(
                                              duration: const Duration(
                                                  milliseconds: 250),
                                              curve: Curves.easeOut,
                                            );
                                          }
                                        },
                                  icon: Icon(_index == _pages.length - 1
                                      ? Icons.check
                                      : Icons.arrow_forward),
                                  label: Text(_index == _pages.length - 1
                                      ? 'Get Started'
                                      : 'Next'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
