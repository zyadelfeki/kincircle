import 'package:flutter/material.dart';

import '../../design/kincircle_screen_tokens.dart';
import 'dashboard_card_container.dart';
import 'sos_hold_button.dart';

class QuickActionsCard extends StatelessWidget {
  const QuickActionsCard({
    super.key,
    this.onSosTap,
    this.onSosTriggered,
    required this.onShareTap,
    required this.onAddPlaceTap,
  });

  final VoidCallback? onSosTap;
  final Future<void> Function()? onSosTriggered;
  final VoidCallback onShareTap;
  final VoidCallback onAddPlaceTap;

  @override
  Widget build(BuildContext context) {
    final palette = KinCirclePalette.of(context);
    return DashboardCardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick actions',
            style: KinCircleTypography.cardTitle16(color: palette.textPrimary),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              // SOS — Press and hold for 3 seconds with filling ring & escalating haptics
              Expanded(
                child: SosHoldButton(
                  onTriggered: onSosTriggered,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ActionButton(
                  icon: Icons.share_location_rounded,
                  label: 'Share location',
                  iconColor: palette.accent,
                  borderColor: palette.border,
                  backgroundColor: palette.surfaceAlt,
                  onTap: onShareTap,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ActionButton(
                  icon: Icons.add_location_alt_rounded,
                  label: 'Add place',
                  iconColor: palette.textPrimary,
                  borderColor: palette.border,
                  backgroundColor: palette.surfaceAlt,
                  onTap: onAddPlaceTap,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.iconColor,
    required this.borderColor,
    required this.backgroundColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color iconColor;
  final Color borderColor;
  final Color backgroundColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = KinCirclePalette.of(context);
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 56),
        side: BorderSide(color: borderColor),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        backgroundColor: backgroundColor,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: iconColor, size: 18),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: KinCircleTypography.caption12(
                color: palette.textPrimary,
                weight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
