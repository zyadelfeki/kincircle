import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../design/kincircle_screen_tokens.dart';

class PrivacyTourScreen extends StatefulWidget {
  const PrivacyTourScreen({super.key});

  @override
  State<PrivacyTourScreen> createState() => _PrivacyTourScreenState();
}

class _PrivacyTourScreenState extends State<PrivacyTourScreen> {
  static const String _privacyTourSeenKey = 'privacy_tour_seen';
  static const List<_PrivacyTourPageData> _pages = <_PrivacyTourPageData>[
    _PrivacyTourPageData(
      icon: Icons.favorite_outline_rounded,
      title: 'Built for your family',
      body:
          "KinCircle keeps your family connected and safer. Here's what we use and why — you stay in control.",
    ),
    _PrivacyTourPageData(
      icon: Icons.location_on_outlined,
      title: 'Location & live updates',
      body:
          'We use your precise location to show family positions on the map and for journey safety. You can pause sharing anytime from the map screen.',
    ),
    _PrivacyTourPageData(
      icon: Icons.directions_car_outlined,
      title: 'Driver safety detection',
      body:
          'We use the accelerometer to detect harsh events like crashes — entirely on your device. You can turn this off in Settings.',
    ),
    _PrivacyTourPageData(
      icon: Icons.tune_rounded,
      title: "You're in control",
      body:
          'You can pause location sharing, export your data, or delete your account at any time from Settings.',
      showLegalLinks: true,
    ),
  ];

  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _checkingSeen = true;
  bool _seen = false;
  bool _isCompleting = false;

  @override
  void initState() {
    super.initState();
    _checkSeenTour();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _checkSeenTour() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    _seen = prefs.getBool(_privacyTourSeenKey) ?? false;
    if (!mounted) return;
    if (_seen) {
      Navigator.of(context).pushReplacementNamed('/home');
      return;
    }
    setState(() {
      _checkingSeen = false;
    });
  }

  Future<void> _onNextPressed() async {
    if (_isCompleting) return;
    final bool isLastPage = _currentPage == _pages.length - 1;
    if (!isLastPage) {
      await _pageController.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOut,
      );
      return;
    }

    setState(() {
      _isCompleting = true;
    });
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_privacyTourSeenKey, true);
    _seen = true;
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/home');
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingSeen) {
      return const Scaffold(
        backgroundColor: KinCirclePalette.background,
        body: SizedBox.expand(),
      );
    }

    final bool isLastPage = _currentPage == _pages.length - 1;

    return Scaffold(
      backgroundColor: KinCirclePalette.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (int page) {
                  setState(() {
                    _currentPage = page;
                  });
                },
                itemBuilder: (BuildContext context, int index) {
                  final _PrivacyTourPageData page = _pages[index];
                  return _PrivacyTourPage(
                    page: page,
                  );
                },
              ),
            ),
            SafeArea(
              top: false,
              minimum: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _PageDots(
                      pageCount: _pages.length,
                      activeIndex: _currentPage,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isCompleting ? null : _onNextPressed,
                        style: KinCircleButtons.primary(),
                        child: Text(isLastPage ? 'Get Started' : 'Next'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrivacyTourPage extends StatelessWidget {
  const _PrivacyTourPage({
    required this.page,
  });

  final _PrivacyTourPageData page;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 8),
      child: Column(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 132,
                  height: 132,
                  decoration: BoxDecoration(
                    color: KinCirclePalette.surface,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: KinCirclePalette.border,
                    ),
                  ),
                  child: Icon(
                    page.icon,
                    color: KinCirclePalette.accent,
                    size: 56,
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  page.title,
                  textAlign: TextAlign.center,
                  style: KinCircleTypography.heading22(
                    weight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  page.body,
                  textAlign: TextAlign.center,
                  style: KinCircleTypography.body14(
                    color: KinCirclePalette.textMuted,
                  ),
                ),
              ],
            ),
          ),
          if (page.showLegalLinks)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                children: [
                  TextButton(
                    onPressed: () =>
                        Navigator.of(context).pushNamed('/privacy-policy'),
                    style: KinCircleButtons.ghost(),
                    child: const Text('Privacy Policy'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pushNamed('/terms'),
                    style: KinCircleButtons.ghost(),
                    child: const Text('Terms of Service'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _PageDots extends StatelessWidget {
  const _PageDots({
    required this.pageCount,
    required this.activeIndex,
  });

  final int pageCount;
  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List<Widget>.generate(pageCount, (int index) {
        final bool active = index == activeIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          height: 10,
          width: active ? 24 : 10,
          decoration: BoxDecoration(
            color: active
                ? KinCirclePalette.accent
                : KinCirclePalette.textMuted.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(999),
          ),
        );
      }),
    );
  }
}

class _PrivacyTourPageData {
  const _PrivacyTourPageData({
    required this.icon,
    required this.title,
    required this.body,
    this.showLegalLinks = false,
  });

  final IconData icon;
  final String title;
  final String body;
  final bool showLegalLinks;
}
