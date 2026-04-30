import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

  Stream<int> _unreadAlertsCountStream() {
    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return Stream<int>.value(0);
    }
    return FirebaseFirestore.instance
        .collection('alerts')
        .where('userId', isEqualTo: uid)
        .where('seen', isEqualTo: false)
        .snapshots()
        .map((QuerySnapshot<Map<String, dynamic>> snapshot) => snapshot.size)
        .handleError((_) {});
  }

  Widget _buildIcon(BuildContext context, _NavItem item, bool active) {
    final palette = KinCirclePalette.of(context);
    final Icon baseIcon = Icon(
      item.icon,
      color: active ? palette.textPrimary : palette.textMuted,
      size: 22,
    );

    if (item.label != 'Alerts') {
      return baseIcon;
    }

    return StreamBuilder<int>(
      stream: _unreadAlertsCountStream(),
      initialData: 0,
      builder: (BuildContext context, AsyncSnapshot<int> snapshot) {
        final int count = snapshot.data ?? 0;
        if (count <= 0) {
          return baseIcon;
        }

        final String badgeText = count > 99 ? '99+' : '$count';
        return Stack(
          clipBehavior: Clip.none,
          children: [
            baseIcon,
            Positioned(
              right: -9,
              top: -7,
              child: Container(
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: palette.error,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  badgeText,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = KinCirclePalette.of(context);
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Container(
        height: 74,
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: palette.border, width: 1),
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
                              ? palette.accent
                              : Colors.transparent,
                          borderRadius: KinCircleRadii.pill,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildIcon(context, item, active),
                      const SizedBox(height: 4),
                      Text(
                        item.label,
                        style: KinCircleTypography.caption12(
                          color: active
                              ? palette.textPrimary
                              : palette.textMuted,
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
