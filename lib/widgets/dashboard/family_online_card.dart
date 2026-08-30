import 'package:flutter/material.dart';

import '../../design/kincircle_screen_tokens.dart';
import '../../models/user_model.dart';
import 'dashboard_card_container.dart';
import 'two_row_skeleton.dart';

class FamilyOnlineCard extends StatelessWidget {
  const FamilyOnlineCard({
    super.key,
    required this.onlineMembers,
    required this.totalCount,
  });

  final List<AppUser>? onlineMembers;
  final int? totalCount;

  @override
  Widget build(BuildContext context) {
    final palette = KinCirclePalette.of(context);
    return DashboardCardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Members Online',
            style: KinCircleTypography.cardTitle16(color: palette.textPrimary),
          ),
          const SizedBox(height: 8),
          if (onlineMembers == null || totalCount == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: TwoRowSkeleton(),
            )
          else if (onlineMembers!.isEmpty || totalCount == 0) ...[
            Text(
              'No one online',
              style: KinCircleTypography.body14(
                color: palette.textPrimary,
                weight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Family members will appear here when they open the app',
              style: KinCircleTypography.caption12(color: palette.textMuted),
            ),
          ] else ...[
            SizedBox(
              height: 32,
              child: Stack(
                children: List<Widget>.generate(
                  onlineMembers!.take(5).length,
                  (int index) {
                    final AppUser user = onlineMembers![index];
                    return Positioned(
                      left: index * 24,
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
              ' /  online',
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
    return ''.toUpperCase();
  }
}
