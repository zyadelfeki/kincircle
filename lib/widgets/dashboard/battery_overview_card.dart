import 'package:flutter/material.dart';

import '../../design/kincircle_screen_tokens.dart';
import '../../models/user_model.dart';
import 'dashboard_card_container.dart';

class BatteryOverviewCard extends StatelessWidget {
  const BatteryOverviewCard({
    super.key,
    required this.member,
    required this.percent,
  });

  final AppUser? member;
  final int? percent;

  @override
  Widget build(BuildContext context) {
    return DashboardCardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Battery Overview', style: KinCircleTypography.cardTitle16()),
          const SizedBox(height: 10),
          if (member == null || percent == null)
            Text(
              'No battery telemetry available',
              style: KinCircleTypography.caption12(color: KinCirclePalette.textMuted),
            )
          else ...[
            Row(
              children: [
                Icon(
                  Icons.battery_alert_rounded,
                  color: _colorFor(percent!),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    member!.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: KinCircleTypography.body14(weight: FontWeight.w600),
                  ),
                ),
                Text(
                  '$percent%',
                  style: KinCircleTypography.body14(
                    color: _colorFor(percent!),
                    weight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: percent! / 100,
                minHeight: 8,
                color: _colorFor(percent!),
                backgroundColor: KinCirclePalette.surfaceAlt,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _colorFor(int p) {
    if (p > 50) return const Color(0xFF22C55E);
    if (p >= 20) return const Color(0xFFF59E0B);
    return KinCirclePalette.error;
  }
}
