import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../../design/kincircle_screen_tokens.dart';
import '../../services/firestore_service.dart';
import '../../services/theme_controller.dart';
import '../../services/privacy_controls_service.dart';
import '../../widgets/nav_shell.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const String _kPushNotifications = 'settings.push_notifications';
  static const String _kAlertSounds = 'settings.alert_sounds';
  static const String _kQuietHours = 'settings.quiet_hours';
  static const String _kLocationSharing = 'settings.location_sharing';
  static const String _kCircleVisibility = 'settings.circle_visibility';

  bool _loading = true;
  bool _pushNotifications = true;
  bool _alertSounds = true;
  bool _quietHours = false;
  bool _locationSharing = true;
  bool _circleVisibility = true;

  String _appLanguage = 'English';
  bool _busyToggle = false;

  final FirestoreService _firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _pushNotifications = prefs.getBool(_kPushNotifications) ?? true;
      _alertSounds = prefs.getBool(_kAlertSounds) ?? true;
      _quietHours = prefs.getBool(_kQuietHours) ?? false;
      _locationSharing = prefs.getBool(_kLocationSharing) ?? true;
      _circleVisibility = prefs.getBool(_kCircleVisibility) ?? true;
      _appLanguage = prefs.getString('settings.app_language') ?? 'English';
      _loading = false;
    });
    _loadPrivacyFromService();
  }

  Future<void> _loadPrivacyFromService() async {
    final String? userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    final PrivacyControlsService privacy =
        context.read<PrivacyControlsService>();
    await privacy.loadPrivacySettings(userId);
    final PrivacySettings? settings = privacy.settings;
    if (settings == null) return;
    if (!mounted) return;
    setState(() {
      _locationSharing = settings.locationSharingEnabled;
    });
  }

  Future<void> _saveBool(String key, bool value) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> _saveString(String key, String value) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  Future<void> _handleLocationSharing(bool value) async {
    if (_busyToggle) return;
    setState(() => _busyToggle = true);
    try {
      final String? userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        final PrivacyControlsService privacy =
            context.read<PrivacyControlsService>();
        await privacy.updateLocationSharing(
          userId: userId,
          enabled: value,
        );
      }
      await _firestoreService.updateVisibility(isInvisible: !value);
      await _saveBool(_kLocationSharing, value);
      if (!mounted) return;
      setState(() => _locationSharing = value);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Unable to update location sharing right now')),
      );
    } finally {
      if (mounted) {
        setState(() => _busyToggle = false);
      }
    }
  }

  Future<void> _showComingSoon() async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Coming soon')),
    );
  }

  bool get _canChangePassword {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    return user.providerData.any((UserInfo info) => info.providerId == 'password');
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.of(context)
        .pushNamedAndRemoveUntil('/auth', (Route<dynamic> route) => false);
  }

  Future<void> _confirmDestructive({
    required String title,
    required String body,
    required VoidCallback onConfirmed,
  }) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: KinCirclePalette.surface,
          title: Text(title, style: KinCircleTypography.cardTitle16()),
          content: Text(
            body,
            style:
                KinCircleTypography.body14(color: KinCirclePalette.textMuted),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text(
                'Confirm',
                style: TextStyle(color: KinCirclePalette.error),
              ),
            ),
          ],
        );
      },
    );
    if (confirm == true) {
      onConfirmed();
    }
  }

  Widget _sectionLabel(String value, {Key? key, Color? color}) {
    return Padding(
      key: key,
      padding: const EdgeInsets.only(left: 16, top: 24, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: KinCircleTypography.caption12(
              color: color ?? KinCirclePalette.accent,
              weight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 1,
            margin: const EdgeInsets.only(right: 16),
            color: KinCirclePalette.border,
          ),
        ],
      ),
    );
  }

  Widget _sectionSpacer() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      height: 6,
      decoration: BoxDecoration(
        color: KinCirclePalette.background.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }

  Widget _row({
    required IconData icon,
    required String title,
    String? subtitle,
    TextStyle? subtitleStyle,
    Widget? trailing,
    Color iconColor = Colors.white,
    Color? titleColor,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: KinCirclePalette.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: KinCirclePalette.border, width: 1),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: iconColor),
        title: Text(
          title,
          style: KinCircleTypography.body14(
            weight: FontWeight.w600,
            color: titleColor ?? KinCirclePalette.textPrimary,
          ),
        ),
        subtitle: subtitle == null
            ? null
            : Text(
                subtitle,
            style: subtitleStyle ??
              KinCircleTypography.caption12(
                color: KinCirclePalette.textMuted),
              ),
        trailing: trailing ??
            const Icon(
              Icons.chevron_right_rounded,
              color: KinCirclePalette.textMuted,
            ),
      ),
    );
  }

  Widget _toggleRow({
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return _row(
      icon: icon,
      title: title,
      trailing: CupertinoSwitch(
        activeTrackColor: KinCirclePalette.accent,
        value: value,
        onChanged: onChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeController themeController = context.watch<ThemeController>();
    final bool isDarkMode = themeController.mode == ThemeMode.dark ||
        (themeController.mode == ThemeMode.system &&
            MediaQuery.of(context).platformBrightness == Brightness.dark);
    return NavShell(
      currentIndex: 4,
      title: 'Profile & Settings',
      automaticallyImplyLeading: false,
      body: _loading
          ? _buildLoadingState()
          : ListView(
              padding: const EdgeInsets.only(bottom: 26),
              children: [
                _sectionLabel('Account'),
                _row(
                  icon: Icons.person_outline,
                  title: 'Edit Profile',
                  onTap: () => Navigator.of(context).pushNamed('/account'),
                ),
                if (_canChangePassword)
                  _row(
                    icon: Icons.lock_outline_rounded,
                    title: 'Change Password',
                    onTap: _showComingSoon,
                  ),
                _sectionSpacer(),
                _sectionLabel('Notifications'),
                _toggleRow(
                  icon: Icons.notifications_active_outlined,
                  title: 'Push notifications',
                  value: _pushNotifications,
                  onChanged: (bool value) async {
                    await _saveBool(_kPushNotifications, value);
                    if (!mounted) return;
                    setState(() => _pushNotifications = value);
                  },
                ),
                _toggleRow(
                  icon: Icons.volume_up_outlined,
                  title: 'Alert sounds',
                  value: _alertSounds,
                  onChanged: (bool value) async {
                    await _saveBool(_kAlertSounds, value);
                    if (!mounted) return;
                    setState(() => _alertSounds = value);
                  },
                ),
                _toggleRow(
                  icon: Icons.nightlight_round,
                  title: 'Quiet hours',
                  value: _quietHours,
                  onChanged: (bool value) async {
                    await _saveBool(_kQuietHours, value);
                    if (!mounted) return;
                    setState(() => _quietHours = value);
                  },
                ),
                _sectionSpacer(),
                _sectionLabel('Privacy'),
                _toggleRow(
                  icon: Icons.location_on_outlined,
                  title: 'Location sharing',
                  value: _locationSharing,
                  onChanged: _handleLocationSharing,
                ),
                _toggleRow(
                  icon: Icons.visibility_outlined,
                  title: 'Visibility to circle members',
                  value: _circleVisibility,
                  onChanged: (bool value) async {
                    await _saveBool(_kCircleVisibility, value);
                    if (!mounted) return;
                    setState(() => _circleVisibility = value);
                  },
                ),
                _sectionSpacer(),
                _sectionLabel('App'),
                _toggleRow(
                  icon: Icons.dark_mode_outlined,
                  title: 'Theme (${isDarkMode ? 'Dark' : 'Light'})',
                  value: isDarkMode,
                  onChanged: (bool value) {
                    themeController
                        .setMode(value ? ThemeMode.dark : ThemeMode.light);
                  },
                ),
                _row(
                  icon: Icons.language_rounded,
                  title: 'App language',
                  subtitle: _appLanguage,
                  onTap: () async {
                    final String? selected = await showModalBottomSheet<String>(
                      context: context,
                      backgroundColor: KinCirclePalette.surface,
                      builder: (BuildContext context) {
                        return SafeArea(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ListTile(
                                title: const Text('English'),
                                onTap: () =>
                                    Navigator.of(context).pop('English'),
                              ),
                              ListTile(
                                title: const Text('Arabic'),
                                onTap: () =>
                                    Navigator.of(context).pop('Arabic'),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                    if (selected == null) return;
                    await _saveString('settings.app_language', selected);
                    if (!mounted) return;
                    setState(() => _appLanguage = selected);
                  },
                ),
                _row(
                  icon: Icons.cleaning_services_outlined,
                  title: 'Clear cache',
                  subtitle: 'Free up local storage',
                  onTap: () async {
                    final ScaffoldMessengerState messenger =
                        ScaffoldMessenger.of(context);
                    final SharedPreferences prefs =
                        await SharedPreferences.getInstance();
                    await prefs.clear();
                    if (!mounted) return;
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Cache cleared')),
                    );
                    await _loadPrefs();
                  },
                ),
                _row(
                  icon: Icons.logout_rounded,
                  title: 'Sign Out',
                  titleColor: KinCirclePalette.error,
                  iconColor: KinCirclePalette.error,
                  onTap: () => _confirmDestructive(
                    title: 'Sign out?',
                    body: 'You can sign back in anytime.',
                    onConfirmed: _signOut,
                  ),
                ),
                _sectionSpacer(),
                _sectionLabel('AI & Wellbeing'),
                _row(
                  icon: Icons.smart_toy_outlined,
                  title: 'Companion Settings',
                  subtitle: 'Your AI family companion',
                  subtitleStyle: const TextStyle(
                    color: Color(0xFF8A8FA8),
                    fontSize: 12,
                  ),
                  onTap: () =>
                      Navigator.of(context).pushNamed('/companion/select'),
                ),
                _row(
                  icon: Icons.analytics_outlined,
                  title: 'Wellbeing Analytics',
                  subtitle: 'Family health insights',
                  subtitleStyle: const TextStyle(
                    color: Color(0xFF8A8FA8),
                    fontSize: 12,
                  ),
                  onTap: () =>
                      Navigator.of(context).pushNamed('/analytics/wellbeing'),
                ),
                _row(
                  icon: Icons.privacy_tip_outlined,
                  title: 'Privacy Dashboard',
                  onTap: () =>
                      Navigator.of(context).pushNamed('/privacy/dashboard'),
                ),
                _sectionSpacer(),
                _sectionLabel('Danger zone', color: KinCirclePalette.error),
                _row(
                  icon: Icons.exit_to_app_rounded,
                  iconColor: KinCirclePalette.textMuted,
                  title: 'Leave Family',
                  onTap: () => _confirmDestructive(
                    title: 'Leave Family?',
                    body: 'You will lose access to family updates.',
                    onConfirmed: _showComingSoon,
                  ),
                ),
                _row(
                  icon: Icons.delete_forever_outlined,
                  iconColor: KinCirclePalette.error,
                  title: 'Delete Account',
                  titleColor: KinCirclePalette.error,
                  onTap: () => _confirmDestructive(
                    title: 'Delete Account?',
                    body: 'This action is permanent.',
                    onConfirmed: _showComingSoon,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildLoadingState() {
    return Shimmer.fromColors(
      baseColor: KinCirclePalette.surfaceAlt,
      highlightColor: KinCirclePalette.border,
      child: ListView.builder(
        itemCount: 9,
        itemBuilder: (_, int index) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
          );
        },
      ),
    );
  }
}
