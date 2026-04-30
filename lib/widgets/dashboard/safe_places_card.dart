import 'package:flutter/material.dart';

import '../../design/kincircle_screen_tokens.dart';
import 'dashboard_card_container.dart';

class SafePlacesCard extends StatelessWidget {
  const SafePlacesCard({
    super.key,
    required this.count,
    required this.onTap,
  });

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = KinCirclePalette.of(context);
    return DashboardCardContainer(
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
Text('Safe Places', style: KinCircleTypography.cardTitle16(color: palette.textPrimary)),
            const SizedBox(height: 10),
            Text(
              '$count',
              style: KinCircleTypography.heading22(color: palette.accent),
            ),
            const SizedBox(height: 8),
            Text(
              count == 0 ? 'Add your first safe place' : 'Tap to manage safe places',
              style: KinCircleTypography.caption12(color: palette.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
