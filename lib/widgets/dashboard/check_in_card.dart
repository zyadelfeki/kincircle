import 'package:flutter/material.dart';

import '../../design/kincircle_screen_tokens.dart';
import 'dashboard_card_container.dart';

class CheckInCard extends StatelessWidget {
  const CheckInCard({
    super.key,
    required this.checkedInToday,
    required this.currentStreak,
    required this.onCheckIn,
    this.isLoading = false,
  });

  final bool checkedInToday;
  final int currentStreak;
  final VoidCallback onCheckIn;
  final bool isLoading;

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
                checkedInToday
                    ? Icons.check_circle_rounded
                    : Icons.health_and_safety_outlined,
                color: checkedInToday ? palette.success : palette.accent,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Daily Check-in',
                  style: KinCircleTypography.cardTitle16(
                    color: palette.textPrimary,
                    weight: FontWeight.w600,
                  ),
                ),
              ),
              if (currentStreak > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.orange.withValues(alpha: 0.4),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🔥', style: TextStyle(fontSize: 12)),
                      const SizedBox(width: 4),
                      Text(
                        ' day',
                        style: KinCircleTypography.caption12(
                          color: Colors.orange.shade700,
                          weight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (checkedInToday) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: palette.success.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: palette.success.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.done_all_rounded, color: palette.success, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Checked in today — I\'m OK',
                          style: KinCircleTypography.body14(
                            color: palette.success,
                            weight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Your circle knows you are safe and sound.',
                          style: KinCircleTypography.caption12(
                            color: palette.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Text(
              'Let your circle know you are safe with a single tap.',
              style: KinCircleTypography.body14(color: palette.textMuted),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: isLoading ? null : onCheckIn,
                style: ElevatedButton.styleFrom(
                  backgroundColor: palette.success,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.sentiment_very_satisfied_rounded,
                        size: 20),
                label: Text(
                  isLoading ? 'Checking in...' : 'I\'m OK',
                  style: KinCircleTypography.body16(
                    color: Colors.white,
                    weight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
