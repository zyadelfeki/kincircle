import 'package:flutter/material.dart';

import '../alerts/alerts_screen.dart';
import '../circles_screen.dart';
import '../map_screen.dart';
import '../places_screen.dart';
import '../settings/settings_screen.dart';

class MainTabsScreen extends StatelessWidget {
  const MainTabsScreen({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  Widget build(BuildContext context) {
    switch (initialIndex) {
      case 1:
        return const CirclesScreen();
      case 2:
        return const PlacesScreen();
      case 3:
        return const AlertsScreen();
      case 4:
        return const SettingsScreen();
      default:
        return const MapScreen();
    }
  }
}
