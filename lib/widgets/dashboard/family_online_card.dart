import 'package:flutter/material.dart';

import '../../design/kincircle_screen_tokens.dart';
import '../../models/user_model.dart';
import 'dashboard_card_container.dart';

class FamilyOnlineCard extends StatelessWidget {
  const FamilyOnlineCard({
    super.key,
    required this.onlineMembers,
    required this.totalCount,
  });

  final List<AppUser> onlineMembers;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    final palette = KinCirclePalette.of(context);
    return DashboardCardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
Text('Members Online', style: KinCircleTypography.cardTitle16(color: palette.textPrimary)),
          const SizedBox(height: 10),
          if (totalCount == 0)
            Text(
              'No members available',
              style: KinCircleTypography.caption12(color: palette.textMuted),
            )
          else ...[
            SizedBox(
              height: 34,
              child: Stack(
                children: List<Widget>.generate(
                  onlineMembers.take(5).length,
                  (int index) {
                    final AppUser user = onlineMembers[index];
                    return Positioned(
                      left: index * 22,
                      child: CircleAvatar(
                        radius: 16,
                        backgroundColor: palette.surfaceAlt,
                        child: Text(
                          _initials(user.displayName),
                          style: KinCircleTypography.caption12(
                            color: palette.textPrimary,
                            weight: FontWeight.w700,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${onlineMembers.length} / $totalCount online',
              style: KinCircleTypography.body14(color: palette.textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  String _initials(String value) {
    final List<String> parts = value
        .trim()
        .split(' ')
        .where((String p) => p.trim().isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}
