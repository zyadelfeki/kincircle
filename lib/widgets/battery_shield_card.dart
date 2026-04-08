import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../design/kincircle_screen_tokens.dart';

class BatteryShieldCard extends StatefulWidget {
  const BatteryShieldCard({super.key});

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
    if (_loading || _dismissed) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: EdgeInsets.zero,
      decoration: BoxDecoration(
        color: KinCirclePalette.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: KinCirclePalette.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 4,
                  height: 40,
                  margin: const EdgeInsets.only(top: 1, right: 10),
                  decoration: BoxDecoration(
                    color: KinCirclePalette.accent,
                    borderRadius: KinCircleRadii.pill,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.shield_outlined,
                    color: KinCirclePalette.accent,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'KinCircle uses adaptive polling - saving your battery vs. always-on GPS',
                    style: KinCircleTypography.body14(
                      color: KinCirclePalette.textPrimary,
                      weight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _dismiss,
                  icon: const Icon(
                    Icons.close,
                    color: KinCirclePalette.textMuted,
                  ),
                  splashRadius: 20,
                  tooltip: 'Dismiss',
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Updating every 30 seconds while moving, every 5 min when still',
              style: KinCircleTypography.caption12(
                color: KinCirclePalette.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
