import 'package:flutter/material.dart';

import '../design/kincircle_screen_tokens.dart';

class BottomNav extends StatelessWidget {
  const BottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const List<_NavItem> _items = <_NavItem>[
    _NavItem(label: 'Map', icon: Icons.map_outlined),
    _NavItem(label: 'Circles', icon: Icons.groups_outlined),
    _NavItem(label: 'Places', icon: Icons.place_outlined),
    _NavItem(label: 'Alerts', icon: Icons.notifications_outlined),
    _NavItem(label: 'Profile', icon: Icons.person_outline),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Container(
        height: 74,
        decoration: BoxDecoration(
          color: KinCirclePalette.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: KinCirclePalette.border, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: List<Widget>.generate(
            _items.length,
            (int index) {
              final bool active = index == currentIndex;
              final _NavItem item = _items[index];
              return Expanded(
                child: InkWell(
                  onTap: () => onTap(index),
                  borderRadius: BorderRadius.circular(999),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        width: active ? 20 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: active
                              ? KinCirclePalette.accent
                              : Colors.transparent,
                          borderRadius: KinCircleRadii.pill,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Icon(
                        item.icon,
                        color: active
                            ? Colors.white
                            : KinCirclePalette.textMuted,
                        size: 22,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.label,
                        style: KinCircleTypography.caption12(
                          color: active
                              ? Colors.white
                              : KinCirclePalette.textMuted,
                          weight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem({required this.label, required this.icon});

  final String label;
  final IconData icon;
}
