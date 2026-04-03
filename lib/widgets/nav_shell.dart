import 'package:flutter/material.dart';

import 'bottom_nav.dart';
import '../design/kincircle_screen_tokens.dart';

class NavShell extends StatelessWidget {
  const NavShell({
    super.key,
    required this.currentIndex,
    required this.body,
    this.title,
    this.actions,
    this.floatingActionButton,
  });

  final int currentIndex;
  final Widget body;
  final String? title;
  final List<Widget>? actions;
  final Widget? floatingActionButton;

  static const List<String> _routes = <String>[
    '/map',
    '/circles',
    '/places',
    '/alerts',
    '/settings',
  ];

  void _onNavTap(BuildContext context, int index) {
    if (index == currentIndex) return;
    Navigator.of(context).pushReplacementNamed(_routes[index]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KinCirclePalette.background,
      appBar: title == null
          ? null
          : AppBar(
              title: Text(
                title!,
                style: KinCircleTypography.cardTitle16(
                  color: KinCirclePalette.textPrimary,
                ),
              ),
              backgroundColor: KinCirclePalette.background,
              elevation: 0,
              actions: actions,
            ),
      body: body,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomNav(
        currentIndex: currentIndex,
        onTap: (int index) => _onNavTap(context, index),
      ),
    );
  }
}
