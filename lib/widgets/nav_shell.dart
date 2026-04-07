import 'package:flutter/material.dart';

import '../screens/alerts/alerts_screen.dart';
import '../screens/circles_screen.dart';
import '../screens/map_screen.dart';
import '../screens/places_screen.dart';
import '../screens/settings/settings_screen.dart';
import 'bottom_nav.dart';
import '../design/kincircle_screen_tokens.dart';

class NavShell extends StatefulWidget {
  const NavShell({
    super.key,
    required this.currentIndex,
    required this.body,
    this.title,
    this.actions,
    this.floatingActionButton,
    this.automaticallyImplyLeading = true,
  });

  final int currentIndex;
  final Widget body;
  final String? title;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final bool automaticallyImplyLeading;

  @override
  State<NavShell> createState() => _NavShellState();
}

class _NavShellState extends State<NavShell> {
  late final PageController _pageController;
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.currentIndex;
    _pageController = PageController(initialPage: widget.currentIndex);
  }

  @override
  void didUpdateWidget(covariant NavShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _selectedIndex = widget.currentIndex;
      _pageController.jumpToPage(widget.currentIndex);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _onNavTap(int index) {
    if (index == _selectedIndex) return;
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  List<Widget> _tabPages() {
    return <Widget>[
      widget.currentIndex == 0
          ? widget.body
          : const _NavShellEmbeddedScope(child: MapScreen()),
      widget.currentIndex == 1
          ? widget.body
          : const _NavShellEmbeddedScope(child: CirclesScreen()),
      widget.currentIndex == 2
          ? widget.body
          : const _NavShellEmbeddedScope(child: PlacesScreen()),
      widget.currentIndex == 3
          ? widget.body
          : const _NavShellEmbeddedScope(child: AlertsScreen()),
      widget.currentIndex == 4
          ? widget.body
          : const _NavShellEmbeddedScope(child: SettingsScreen()),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (_NavShellEmbeddedScope.isInScope(context)) {
      return widget.body;
    }

    return Scaffold(
      backgroundColor: KinCirclePalette.background,
      appBar: widget.title == null
          ? null
          : AppBar(
              automaticallyImplyLeading: widget.automaticallyImplyLeading,
              title: Text(
                widget.title!,
                style: KinCircleTypography.cardTitle16(
                  color: KinCirclePalette.textPrimary,
                ),
              ),
              backgroundColor: KinCirclePalette.background,
              elevation: 0,
              actions: widget.actions,
            ),
      body: PageView(
        controller: _pageController,
        physics: const PageScrollPhysics(),
        onPageChanged: _onPageChanged,
        children: _tabPages(),
      ),
      floatingActionButton: widget.floatingActionButton,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomNav(
        currentIndex: _selectedIndex,
        onTap: _onNavTap,
      ),
    );
  }
}

class _NavShellEmbeddedScope extends InheritedWidget {
  const _NavShellEmbeddedScope({
    required super.child,
  });

  static bool isInScope(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<_NavShellEmbeddedScope>() !=
        null;
  }

  @override
  bool updateShouldNotify(covariant InheritedWidget oldWidget) => false;
}
