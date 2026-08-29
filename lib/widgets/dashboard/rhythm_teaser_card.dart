import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../design/kincircle_screen_tokens.dart';
import 'dashboard_card_container.dart';

/// Dismissible teaser card shown to free users explaining rhythm learning.
class RhythmTeaserCard extends StatefulWidget {
  const RhythmTeaserCard({
    super.key,
    this.onUpgradeTap,
  });

  static const String prefsKey = 'rhythm.teaser.dismissed';

  final VoidCallback? onUpgradeTap;

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
    if (_dismissed) {
      return const SizedBox.shrink();
    }

    final palette = KinCirclePalette.of(context);

    return DashboardCardContainer(
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 28),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: palette.accent.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    color: palette.accent,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
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
                      const SizedBox(height: 4),
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
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
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
                              const SizedBox(width: 4),
                              Icon(
                                Icons.arrow_forward_rounded,
                                color: palette.accent,
                                size: 14,
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
            top: -6,
            right: -6,
            child: IconButton(
              icon: Icon(
                Icons.close_rounded,
                color: palette.textMuted,
                size: 18,
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
