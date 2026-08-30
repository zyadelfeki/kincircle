import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../design/kincircle_screen_tokens.dart';
import 'dashboard/two_row_skeleton.dart';

class BatteryShieldCard extends StatefulWidget {
  const BatteryShieldCard({
    super.key,
    this.isLoading = false,
    this.isAvailable = true,
  });

  final bool isLoading;
  final bool isAvailable;

  @override
  State<BatteryShieldCard> createState() => _BatteryShieldCardState();
}

class _BatteryShieldCardState extends State<BatteryShieldCard> {
  static const String _dismissedKey = 'ui.batteryShieldDismissed';

  bool _loading = true;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _loadDismissedState();
  }

  Future<void> _loadDismissedState() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final bool dismissed = prefs.getBool(_dismissedKey) ?? false;
    if (!mounted) return;
    setState(() {
      _dismissed = dismissed;
      _loading = false;
    });
  }

  Future<void> _dismiss() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_dismissedKey, true);
    if (!mounted) return;
    setState(() {
      _dismissed = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = KinCirclePalette.of(context);

    if (widget.isLoading) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: KinCircleRadii.card,
          border: Border.all(color: palette.border),
        ),
        child: const TwoRowSkeleton(),
      );
    }

    if (!widget.isAvailable) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: KinCircleRadii.card,
          border: Border.all(color: palette.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
          ],
        ),
      );
    }

    if (_loading || _dismissed) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: EdgeInsets.zero,
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: KinCircleRadii.card,
        border: Border.all(color: palette.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 4,
                  height: 32,
                  margin: const EdgeInsets.only(top: 2, right: 8),
                  decoration: BoxDecoration(
                    color: palette.accent,
                    borderRadius: KinCircleRadii.pill,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.shield_outlined,
                    color: palette.accent,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'KinCircle uses adaptive polling - saving your battery vs. always-on GPS',
                    style: KinCircleTypography.body14(
                      color: palette.textPrimary,
                      weight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _dismiss,
                  icon: Icon(
                    Icons.close,
                    color: palette.textMuted,
                    size: 16,
                  ),
                  splashRadius: 16,
                  tooltip: 'Dismiss',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Updating every 30 seconds while moving, every 5 min when still',
              style: KinCircleTypography.caption12(
                color: palette.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
