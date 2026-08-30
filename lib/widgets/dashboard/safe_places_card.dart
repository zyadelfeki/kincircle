import 'package:flutter/material.dart';

import '../../design/kincircle_screen_tokens.dart';
import 'dashboard_card_container.dart';
import 'two_row_skeleton.dart';

class SafePlacesCard extends StatelessWidget {
  const SafePlacesCard({
    super.key,
    required this.count,
    required this.onTap,
  });

  final int? count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = KinCirclePalette.of(context);
    return DashboardCardContainer(
      child: InkWell(
        onTap: onTap,
        borderRadius: KinCircleRadii.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Safe Places',
              style: KinCircleTypography.cardTitle16(color: palette.textPrimary),
            ),
            const SizedBox(height: 8),
            if (count == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: TwoRowSkeleton(),
              )
            else if (count == 0) ...[
              Text(
                'No safe places yet',
                style: KinCircleTypography.body14(
                  color: palette.textPrimary,
                  weight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Add your first safe place to get alerts when family arrives or leaves',
                style: KinCircleTypography.caption12(color: palette.textMuted),
              ),
            ] else ...[
              Text(
                '',
                style: KinCircleTypography.heading22(color: palette.accent),
              ),
              const SizedBox(height: 8),
              Text(
                'Tap to manage safe places',
                style: KinCircleTypography.caption12(color: palette.textMuted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
