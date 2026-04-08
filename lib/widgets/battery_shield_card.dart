import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      color: colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.shield_outlined,
                    color: colorScheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'KinCircle uses adaptive polling - saving your battery vs. always-on GPS',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _dismiss,
                  icon: Icon(Icons.close, color: colorScheme.onSurfaceVariant),
                  splashRadius: 20,
                  tooltip: 'Dismiss',
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Updating every 30 seconds while moving, every 5 min when still',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
