import 'package:flutter/material.dart';

import '../../design/kincircle_screen_tokens.dart';
import '../../models/user_model.dart';
import '../../services/rhythm/rhythm_store.dart';
import 'dashboard_card_container.dart';

/// Card on the dashboard visible to everyone showing real-time rhythm baseline learning progress per member.
class FamilyRhythmsCard extends StatelessWidget {
  const FamilyRhythmsCard({
    super.key,
    required this.members,
    this.rhythmStore,
  });

  final List<AppUser> members;
  final RhythmStore? rhythmStore;

  RhythmStore get _store => rhythmStore ?? RhythmStore.instance;

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

  @override
  Widget build(BuildContext context) {
    final palette = KinCirclePalette.of(context);

    return DashboardCardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.schedule_rounded,
                size: 20,
                color: palette.accent,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Family rhythms',
                  style: KinCircleTypography.cardTitle16(
                    color: palette.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: palette.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'On-Device AI',
                  style: KinCircleTypography.caption12(
                    color: palette.accent,
                    weight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (members.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Add family members to learn shared arrival rhythms.',
                style: KinCircleTypography.body14(color: palette.textMuted),
              ),
            )
          else
            ...members.map((AppUser member) {
              final List<RhythmBaseline> baselines =
                  _store.getAllBaselines(userId: member.uid);

              int maxSamples = 0;
              RhythmBaseline? bestBaseline;

              for (final baseline in baselines) {
                if (baseline.sampleCount > maxSamples) {
                  maxSamples = baseline.sampleCount;
                  bestBaseline = baseline;
                }
              }

              final bool isActive = maxSamples >= 5;
              final String statusLabel = isActive
                  ? (bestBaseline != null
                      ? 'Active · ~${bestBaseline.formattedArrival}'
                      : 'Active')
                  : 'Learning — $maxSamples of 5 samples';

              final double progress = (maxSamples / 5.0).clamp(0.0, 1.0);

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: palette.surfaceAlt,
                      child: Text(
                        _initials(member.displayName),
                        style: KinCircleTypography.caption12(
                          color: palette.textPrimary,
                          weight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            member.displayName.isNotEmpty
                                ? member.displayName
                                : 'Family member',
                            style: KinCircleTypography.body14(
                              color: palette.textPrimary,
                              weight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            statusLabel,
                            style: KinCircleTypography.caption12(
                              color: isActive
                                  ? palette.accent
                                  : palette.textMuted,
                              weight:
                                  isActive ? FontWeight.w600 : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (isActive)
                      Icon(
                        Icons.check_circle_rounded,
                        size: 18,
                        color: palette.accent,
                      )
                    else
                      SizedBox(
                        width: 50,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 6,
                            backgroundColor: palette.surfaceAlt,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              palette.accent,
                            ),
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
