import 'package:flutter/material.dart';

import '../../design/kincircle_screen_tokens.dart';
import 'dashboard_card_container.dart';

class RecentActivityItem {
  const RecentActivityItem({
    required this.title,
    required this.subtitle,
    required this.timeLabel,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final String timeLabel;
  final IconData icon;
}

class RecentActivityCard extends StatelessWidget {
  const RecentActivityCard({
    super.key,
    required this.items,
  });

  final List<RecentActivityItem> items;

  @override
  Widget build(BuildContext context) {
    final palette = KinCirclePalette.of(context);
    return DashboardCardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Recent Activity', style: KinCircleTypography.cardTitle16(color: palette.textPrimary)),
          const SizedBox(height: 8),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.history_toggle_off, color: palette.textMuted),
                    const SizedBox(height: 8),
                    Text(
                      'No recent events yet',
                      style: KinCircleTypography.caption12(
                        color: palette.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...items.take(5).map((RecentActivityItem item) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: palette.surfaceAlt,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(item.icon, size: 16, color: palette.accent),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: KinCircleTypography.body14(weight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            item.subtitle,
                            style: KinCircleTypography.caption12(
                              color: palette.textMuted,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.timeLabel,
                        style: KinCircleTypography.caption12(
                          color: palette.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
