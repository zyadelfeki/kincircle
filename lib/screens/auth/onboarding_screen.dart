import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class _OnboardingPage {
  final IconData icon;
  final String title;
  final String body;
  final String? preAsk;
  final bool successState;

  const _OnboardingPage({
    required this.icon,
    required this.title,
    required this.body,
    this.preAsk,
    this.successState = false,
  });
}

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

  static const _pages = [
    _OnboardingPage(
      icon: Icons.diversity_3,
      title: 'Your family,\nalways connected',
      body:
          'KinCircle keeps everyone in the loop - quietly, privately, and only when it matters.',
    ),
    _OnboardingPage(
      icon: Icons.map_outlined,
      title: 'See where\neveryone is',
      body:
          'A calm map shows your circle in real time. No clutter - just the people you care about.',
      preAsk:
          '📍 On the next step, we\'ll ask for location access. This is what powers the family map and safety alerts.',
    ),
    _OnboardingPage(
      icon: Icons.shield_outlined,
      title: 'You\'re always\nin control',
      body:
          'Choose exactly what to share and when. Pause sharing anytime from settings.',
      preAsk:
          '🔔 We\'ll also ask for notifications - so you hear about arrivals, alerts, and safety events as they happen.',
    ),
    _OnboardingPage(
      icon: Icons.check_circle_outline,
      title: 'You\'re in\nthe circle',
      body:
          'Let\'s set up your permissions so KinCircle can protect your family.',
      successState: true,
    ),
  ];

  Future<void> _complete() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final userId = widget.userId;
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .set({'onboardingComplete': true}, SetOptions(merge: true));
    } catch (_) {}
    if (!mounted) return;
    // After onboarding, guide users to enable core permissions.
    Navigator.of(context).pushReplacementNamed('/permissions');
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    Future<void> nextOrComplete() async {
      if (_index == _pages.length - 1) {
        await _complete();
        return;
      }
      await _controller.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }

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
                  final _OnboardingPage p = _pages[i];
                  final bool isLast = i == _pages.length - 1;
                  final Color iconColor =
                      p.successState ? Colors.green : scheme.primary;

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
                              ?.copyWith(color: scheme.onSurfaceVariant),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        Expanded(
                          child: Center(
                            child: Container(
                              width: 220,
                              height: 220,
                              decoration: BoxDecoration(
                                color: iconColor.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                p.icon,
                                size: 120,
                                color: iconColor,
                              ),
                            ),
                          ),
                        ),
                        if (p.preAsk != null) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color:
                                  scheme.surfaceContainerHighest.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: scheme.outlineVariant),
                            ),
                            child: Text(
                              p.preAsk!,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                                height: 1.35,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(_pages.length, (dot) {
                            final active = dot == _index;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.symmetric(horizontal: 4),
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
                        if (!isLast)
                          Row(
                            children: [
                              TextButton(
                                onPressed: _saving ? null : _complete,
                                child: const Text('Skip'),
                              ),
                              const Spacer(),
                              FilledButton.icon(
                                onPressed: _saving ? null : nextOrComplete,
                                icon: const Icon(Icons.arrow_forward),
                                label: const Text('Next'),
                              ),
                            ],
                          )
                        else
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: _saving ? null : _complete,
                              style: FilledButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                              ),
                              child: const Text('Set Up KinCircle'),
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
      ),
    );
  }
}
