import 'package:flutter/material.dart';

import '../../design/kincircle_screen_tokens.dart';
import 'dashboard_card_container.dart';

class ActiveAlertsCard extends StatelessWidget {
  const ActiveAlertsCard({
    super.key,
    required this.count,
    required this.lastPreview,
    required this.onTap,
  });

  final int count;
  final String? lastPreview;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DashboardCardContainer(
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: KinCirclePalette.error),
                const SizedBox(width: 8),
                Text('Active Alerts', style: KinCircleTypography.cardTitle16()),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '$count',
              style: KinCircleTypography.heading22(
                color: count > 0 ? KinCirclePalette.error : KinCirclePalette.accent,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              count == 0
                  ? 'No active alerts'
                  : (lastPreview?.trim().isNotEmpty == true
                      ? lastPreview!
                      : 'Tap to review alerts'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: KinCircleTypography.caption12(
                color: KinCirclePalette.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
