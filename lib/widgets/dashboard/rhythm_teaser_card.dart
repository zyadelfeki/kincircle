import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../design/kincircle_screen_tokens.dart';
import 'dashboard_card_container.dart';
import 'two_row_skeleton.dart';

/// Dismissible teaser card explaining rhythm learning or empty state when no predictions exist.
class RhythmTeaserCard extends StatefulWidget {
  const RhythmTeaserCard({
    super.key,
    this.onUpgradeTap,
    this.isLoading = false,
    this.hasPredictions,
  });

  static const String prefsKey = 'rhythm.teaser.dismissed';

  final VoidCallback? onUpgradeTap;
  final bool isLoading;
  final bool? hasPredictions;

  @override
  State<RhythmTeaserCard> createState() => _RhythmTeaserCardState();
}

class _RhythmTeaserCardState extends State<RhythmTeaserCard> {
  bool _dismissed = true;

  @override
  void initState() {
    super.initState();
    _checkDismissed();
  }

  Future<void> _checkDismissed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bool isDismissed = prefs.getBool(RhythmTeaserCard.prefsKey) ?? false;
      if (mounted) {
        setState(() {
          _dismissed = isDismissed;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _dismissed = false;
        });
      }
    }
  }

  Future<void> _dismiss() async {
    setState(() {
      _dismissed = true;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(RhythmTeaserCard.prefsKey, true);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return const DashboardCardContainer(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: TwoRowSkeleton(),
        ),
      );
    }

    if (widget.hasPredictions == false) {
      final palette = KinCirclePalette.of(context);
      return DashboardCardContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  color: palette.accent,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'No rhythm predictions yet',
                  style: KinCircleTypography.cardTitle16(
                    color: palette.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              "Check in daily to build your family's movement patterns",
              style: KinCircleTypography.body14(
                color: palette.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    if (_dismissed) {
      return const SizedBox.shrink();
    }

    final palette = KinCirclePalette.of(context);

    return DashboardCardContainer(
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 32),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: palette.accent.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    color: palette.accent,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Family Rhythm AI',
                        style: KinCircleTypography.cardTitle16(
                          color: palette.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "KinCircle is learning your family's rhythms. Pro members get pattern-break alerts.",
                        style: KinCircleTypography.body14(
                          color: palette.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: widget.onUpgradeTap ??
                            () => Navigator.of(context).pushNamed('/subscription'),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Explore Pro',
                                style: KinCircleTypography.caption12(
                                  color: palette.accent,
                                  weight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.arrow_forward_rounded,
                                color: palette.accent,
                                size: 16,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: IconButton(
              icon: Icon(
                Icons.close_rounded,
                color: palette.textMuted,
                size: 16,
              ),
              onPressed: _dismiss,
              tooltip: 'Dismiss',
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
    );
  }
}
