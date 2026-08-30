import 'package:flutter/material.dart';

import '../../design/kincircle_screen_tokens.dart';
import '../../models/user_model.dart';
import 'dashboard_card_container.dart';
import 'two_row_skeleton.dart';

class BatteryOverviewCard extends StatelessWidget {
  const BatteryOverviewCard({
    super.key,
    required this.member,
    required this.percent,
    this.isLoading = false,
  });

  final AppUser? member;
  final int? percent;
  final bool isLoading;

  bool get _isSignalLost {
    if (member == null || member!.lastUpdated == null) return false;
    return DateTime.now().difference(member!.lastUpdated!) > const Duration(hours: 3);
  }

  @override
  Widget build(BuildContext context) {
    final palette = KinCirclePalette.of(context);
    final signalLost = _isSignalLost;

    return DashboardCardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Battery overview',
            style: KinCircleTypography.cardTitle16(color: palette.textPrimary),
          ),
          const SizedBox(height: 8),
          if (isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: TwoRowSkeleton(),
            )
          else if (member == null || percent == null) ...[
            Text(
              'Battery data unavailable',
              style: KinCircleTypography.body14(
                color: palette.textPrimary,
                weight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ensure family members have location and battery permissions enabled',
              style: KinCircleTypography.caption12(color: palette.textMuted),
            ),
          ] else if (signalLost) ...[
            Row(
              children: [
                Icon(
                  Icons.signal_cellular_connected_no_internet_0_bar_rounded,
                  color: palette.textMuted,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    member!.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: KinCircleTypography.body14(
                      color: palette.textPrimary,
                      weight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'signal lost',
                  style: KinCircleTypography.body14(
                    color: palette.textMuted,
                    weight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ] else ...[
            Row(
              children: [
                Icon(
                  Icons.battery_alert_rounded,
                  color: _colorFor(palette, percent!),
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    member!.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: KinCircleTypography.body14(
                      color: palette.textPrimary,
                      weight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '%',
                  style: KinCircleTypography.body14(
                    color: _colorFor(palette, percent!),
                    weight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: percent! / 100,
                color: _colorFor(palette, percent!),
                backgroundColor: palette.surfaceAlt,
                minHeight: 8,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _colorFor(KinCirclePaletteData palette, int p) {
    if (p <= 20) return palette.error;
    if (p <= 50) return palette.warning;
    return palette.success;
  }
}
