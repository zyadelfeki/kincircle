import 'package:flutter/material.dart';

import '../../design/kincircle_screen_tokens.dart';
import 'dashboard_card_container.dart';

class QuickActionsCard extends StatelessWidget {
  const QuickActionsCard({
    super.key,
    required this.onSosTap,
    required this.onShareTap,
    required this.onAddPlaceTap,
  });

  final VoidCallback onSosTap;
  final VoidCallback onShareTap;
  final VoidCallback onAddPlaceTap;

  @override
  Widget build(BuildContext context) {
    final palette = KinCirclePalette.of(context);
    return DashboardCardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
Text('Quick Actions', style: KinCircleTypography.cardTitle16(color: palette.textPrimary)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  icon: Icons.sos_rounded,
                  label: 'SOS',
                  color: palette.error,
                  borderColor: palette.border,
                  onTap: onSosTap,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ActionButton(
                  icon: Icons.share_location_rounded,
                  label: 'Share Location',
                  color: palette.accent,
                  borderColor: palette.border,
                  onTap: onShareTap,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ActionButton(
                  icon: Icons.add_location_alt_rounded,
                  label: 'Add Place',
                  color: palette.textPrimary,
                  borderColor: palette.border,
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
    required this.color,
    required this.borderColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color borderColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = KinCirclePalette.of(context);
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 56),
side: BorderSide(color: palette.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        backgroundColor: palette.surfaceAlt,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: KinCircleTypography.caption12(color: palette.textPrimary, weight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
