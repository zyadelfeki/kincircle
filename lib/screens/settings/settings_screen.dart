import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';

import '../../design/kincircle_screen_tokens.dart';
import '../../services/firestore_service.dart';
import '../../services/privacy_controls_service.dart';
import '../../services/theme_controller.dart';
import '../../widgets/nav_shell.dart';

class SettingsScreen extends StatefulWidget {
  final FirestoreService? firestoreService;

  const SettingsScreen({
    super.key,
    this.firestoreService,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const String _kPushNotifications = 'settings.push_notifications';
  static const String _kAlertSounds = 'settings.alert_sounds';
  static const String _kQuietHours = 'settings.quiet_hours';
  static const String _kLocationSharing = 'settings.location_sharing';
  static const String _kCircleVisibility = 'settings.circle_visibility';
  static const String _kAppLanguage = 'settings.app_language';

  bool _loading = true;
  bool _pushNotifications = true;
  bool _alertSounds = true;
  bool _quietHours = false;
  bool _locationSharing = true;
  bool _circleVisibility = true;
  String _appLanguage = 'English';
  String _userRole = 'family_member';
  bool _busyLocationToggle = false;

  User? get _currentUser {
    try {
      return FirebaseAuth.instance.currentUser;
    } catch (_) {
      return null;
    }
  }

  late final FirestoreService _firestoreService;

  @override
  void initState() {
    super.initState();
    _firestoreService = widget.firestoreService ?? FirestoreService();
    _loadAllSettings();
  }

  Future<void> _loadAllSettings() async {
    PrivacyControlsService? privacy;
    try {
      privacy = context.read<PrivacyControlsService>();
    } catch (_) {}

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final User? user = _currentUser;

    bool push = prefs.getBool(_kPushNotifications) ?? true;
    bool sound = prefs.getBool(_kAlertSounds) ?? true;
    bool quiet = prefs.getBool(_kQuietHours) ?? false;
    bool locSharing = prefs.getBool(_kLocationSharing) ?? true;
    bool visibility = prefs.getBool(_kCircleVisibility) ?? true;
    String lang = prefs.getString(_kAppLanguage) ?? 'English';
    String role = 'family_member';

    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get()
            .timeout(const Duration(seconds: 4));
        if (doc.exists) {
          final data = doc.data();
          if (data != null) {
            role = (data['role'] as String?) ?? 'family_member';
            if (data.containsKey('notificationsEnabled')) {
              push = data['notificationsEnabled'] as bool;
            }
          }
        }
      } catch (_) {}

      if (privacy != null) {
        try {
          await privacy.loadPrivacySettings(user.uid);
          if (privacy.settings != null) {
            locSharing = privacy.settings!.locationSharingEnabled;
          }
        } catch (_) {}
      }
    }

    if (!mounted) return;
    setState(() {
      _pushNotifications = push;
      _alertSounds = sound;
      _quietHours = quiet;
      _locationSharing = locSharing;
      _circleVisibility = visibility;
      _appLanguage = lang;
      _userRole = role;
      _loading = false;
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

  Future<void> _handlePushNotificationToggle(bool value) async {
    setState(() => _pushNotifications = value);
    await _saveBool(_kPushNotifications, value);

    final User? user = _currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set({
          'notificationsEnabled': value,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (_) {}
    }
  }

  Future<void> _handleLocationSharingToggle(bool value) async {
    if (_busyLocationToggle) return;
    setState(() {
      _busyLocationToggle = true;
      _locationSharing = value;
    });

    try {
      final User? user = _currentUser;
      if (user != null) {
        final PrivacyControlsService privacy =
            context.read<PrivacyControlsService>();
        await privacy.updateLocationSharing(
          userId: user.uid,
          enabled: value,
        );
      }
      await _firestoreService.updateVisibility(isInvisible: !value);
      await _saveBool(_kLocationSharing, value);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to update location sharing right now'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _busyLocationToggle = false);
      }
    }
  }

  Future<void> _handleLocationModePicker() async {
    final User? user = _currentUser;
    if (user == null) return;
    final privacy = context.read<PrivacyControlsService>();
    final currentMode =
        privacy.settings?.locationSharingMode ?? LocationSharingMode.familyOnly;

    final palette = KinCirclePalette.of(context);
    final LocationSharingMode? selected =
        await showModalBottomSheet<LocationSharingMode>(
      context: context,
      backgroundColor: palette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Location Sharing Mode',
                    style: KinCircleTypography.cardTitle16(
                      color: palette.textPrimary,
                      weight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _modeTile(
                  ctx,
                  palette,
                  'Always',
                  'Share live location continuously',
                  LocationSharingMode.everyone,
                  currentMode == LocationSharingMode.everyone,
                ),
                _modeTile(
                  ctx,
                  palette,
                  'Circle Only',
                  'Share only when circle members request or nearby',
                  LocationSharingMode.familyOnly,
                  currentMode == LocationSharingMode.familyOnly,
                ),
                _modeTile(
                  ctx,
                  palette,
                  'Emergency Only',
                  'Share only when an SOS is triggered',
                  LocationSharingMode.emergencyOnly,
                  currentMode == LocationSharingMode.emergencyOnly,
                ),
                _modeTile(
                  ctx,
                  palette,
                  'Off',
                  'Pause all location broadcasts',
                  LocationSharingMode.disabled,
                  currentMode == LocationSharingMode.disabled,
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selected != null) {
      await privacy.updateLocationSharing(
        userId: user.uid,
        enabled: selected != LocationSharingMode.disabled,
        mode: selected,
      );
      await _firestoreService.updateVisibility(
        isInvisible: selected == LocationSharingMode.disabled,
      );
      await _saveBool(
        _kLocationSharing,
        selected != LocationSharingMode.disabled,
      );
      if (mounted) {
        setState(() {
          _locationSharing = selected != LocationSharingMode.disabled;
        });
      }
    }
  }

  Widget _modeTile(
    BuildContext ctx,
    KinCirclePaletteData palette,
    String title,
    String subtitle,
    LocationSharingMode mode,
    bool isSelected,
  ) {
    return ListTile(
      title: Text(
        title,
        style: KinCircleTypography.body14(
          color: isSelected ? palette.accent : palette.textPrimary,
          weight: isSelected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: KinCircleTypography.caption12(color: palette.textMuted),
      ),
      trailing: isSelected
          ? Icon(Icons.check_circle, color: palette.accent, size: 20)
          : null,
      onTap: () => Navigator.of(ctx).pop(mode),
    );
  }

  Future<void> _handleSafeClearCache() async {
    final messenger = ScaffoldMessenger.of(context);
    final palette = KinCirclePalette.of(context);

    // Purge only in-memory image cache - preserve prefs, auth, Pro status
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();

    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: const Text('Image & temporary cache cleared'),
        backgroundColor: palette.success,
      ),
    );
  }

  Future<void> _showChangePasswordDialog() async {
    final String email = _currentUser?.email ?? '';
    final palette = KinCirclePalette.of(context);
    final emailController = TextEditingController(text: email);

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: palette.surface,
        title: Text(
          'Reset Password',
          style: KinCircleTypography.cardTitle16(
            color: palette.textPrimary,
            weight: FontWeight.w700,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "We'll send a password reset link to your registered email address.",
              style: KinCircleTypography.body14(color: palette.textMuted),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: KinCircleDecorations.input(palette),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: TextField(
                controller: emailController,
                readOnly: true,
                style: KinCircleTypography.body14(color: palette.textPrimary),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  labelText: 'Email',
                  labelStyle:
                      KinCircleTypography.caption12(color: palette.textMuted),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Cancel',
              style: KinCircleTypography.body14(color: palette.textMuted),
            ),
          ),
          ElevatedButton(
            style: KinCircleButtons.primary(),
            onPressed: () async {
              final nav = Navigator.of(ctx);
              final messenger = ScaffoldMessenger.of(context);
              try {
                await FirebaseAuth.instance.sendPasswordResetEmail(
                  email: emailController.text.trim(),
                );
                nav.pop();
                messenger.showSnackBar(
                  SnackBar(
                    content: const Text('Password reset email sent!'),
                    backgroundColor: palette.success,
                  ),
                );
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Error: $e'),
                    backgroundColor: palette.error,
                  ),
                );
              }
            },
            child: const Text('Send Reset Link'),
          ),
        ],
      ),
    );
    emailController.dispose();
  }

  bool get _canChangePassword {
    final User? user = _currentUser;
    if (user == null) return false;
    return user.providerData
        .any((UserInfo info) => info.providerId == 'password');
  }

  Future<void> _signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
    if (!mounted) return;
    Navigator.of(context)
        .pushNamedAndRemoveUntil('/auth', (Route<dynamic> route) => false);
  }

  Future<void> _handleLeaveFamily() async {
    final String? familyId = await _firestoreService.getCurrentFamilyId();
    if (familyId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You are not currently in a circle')),
      );
      return;
    }
    await _confirmDestructive(
      title: 'Leave circle?',
      body: 'You will lose access to this circle and its live safety updates.',
      onConfirmed: () async {
        try {
          await _firestoreService.leaveFamily(familyId);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Left circle successfully')),
          );
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to leave circle: $e')),
          );
        }
      },
    );
  }

  Future<void> _handleDeleteAccount() async {
    await _confirmDestructive(
      title: 'Delete account?',
      body:
          'This action is permanent and will completely erase your account and data.',
      onConfirmed: () async {
        try {
          final user = _currentUser;
          if (user != null) {
            await user.delete();
          }
          if (!mounted) return;
          Navigator.of(context)
              .pushNamedAndRemoveUntil('/auth', (route) => false);
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Failed to delete account (may require recent login): $e'),
            ),
          );
        }
      },
    );
  }

  Future<void> _confirmDestructive({
    required String title,
    required String body,
    required VoidCallback onConfirmed,
  }) async {
    final palette = KinCirclePalette.of(context);
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: palette.surface,
          title: Text(
            title,
            style: KinCircleTypography.cardTitle16(
              color: palette.textPrimary,
              weight: FontWeight.w700,
            ),
          ),
          content: Text(
            body,
            style: KinCircleTypography.body14(color: palette.textMuted),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Cancel',
                style: KinCircleTypography.body14(color: palette.textMuted),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                'Confirm',
                style: KinCircleTypography.body14(
                  color: palette.error,
                  weight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );
    if (confirm == true) {
      await HapticFeedback.heavyImpact();
      onConfirmed();
    }
  }

  String _formatRole(String role) {
    switch (role) {
      case 'caregiver':
        return 'Caregiver';
      case 'care_recipient':
        return 'Care Recipient';
      case 'parent':
        return 'Parent';
      case 'child':
        return 'Child';
      default:
        return 'Member';
    }
  }

  Widget _sectionLabel(String value, {Color? color}) {
    final palette = KinCirclePalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 16, top: 24, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: KinCircleTypography.caption12(
              color: color ?? palette.textMuted,
              weight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 1,
            margin: const EdgeInsets.only(right: 16),
            color: palette.border,
          ),
        ],
      ),
    );
  }

  Widget _row({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    Color? iconColor,
    Color? titleColor,
    VoidCallback? onTap,
  }) {
    final palette = KinCirclePalette.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.border, width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: ListTile(
          onTap: onTap,
          leading: Icon(icon, color: iconColor ?? palette.textSecondary),
          title: Text(
            title,
            style: KinCircleTypography.body14(
              weight: FontWeight.w600,
              color: titleColor ?? palette.textPrimary,
            ),
          ),
          subtitle: subtitle == null
              ? null
              : Text(
                  subtitle,
                  style: KinCircleTypography.caption12(
                    color: palette.textMuted,
                  ),
                ),
          trailing: trailing ??
              Icon(
                Icons.chevron_right_rounded,
                color: palette.textMuted,
              ),
        ),
      ),
    );
  }

  Widget _toggleRow({
    required IconData icon,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final palette = KinCirclePalette.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.border, width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: ListTile(
          leading: Icon(icon, color: palette.textSecondary),
          title: Text(
            title,
            style: KinCircleTypography.body14(
              weight: FontWeight.w600,
              color: palette.textPrimary,
            ),
          ),
          subtitle: subtitle == null
              ? null
              : Text(
                  subtitle,
                  style: KinCircleTypography.caption12(
                    color: palette.textMuted,
                  ),
                ),
          trailing: CupertinoSwitch(
            activeTrackColor: palette.accent,
            value: value,
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }

  Widget _buildUserHeaderCard(
    KinCirclePaletteData palette,
    User? user,
    bool isPro,
  ) {
    final displayName = user?.displayName ?? 'KinCircle Member';
    final email = user?.email ?? '';
    final initial = displayName.isNotEmpty
        ? displayName[0].toUpperCase()
        : (email.isNotEmpty ? email[0].toUpperCase() : 'U');

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border, width: 1),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: palette.accent.withValues(alpha: 0.2),
            backgroundImage:
                user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
            child: user?.photoURL == null
                ? Text(
                    initial,
                    style: KinCircleTypography.heading22(
                      color: palette.accent,
                      weight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        displayName,
                        style: KinCircleTypography.body16(
                          color: palette.textPrimary,
                          weight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isPro) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: palette.warning.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: palette.warning),
                        ),
                        child: Text(
                          'PRO',
                          style: KinCircleTypography.caption10(
                            color: palette.warning,
                            weight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: KinCircleTypography.caption12(
                    color: palette.textMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: palette.surfaceAlt,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: palette.border),
                  ),
                  child: Text(
                    _formatRole(_userRole),
                    style: KinCircleTypography.caption10(
                      color: palette.textSecondary,
                      weight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = KinCirclePalette.of(context);
    final themeController = context.watch<ThemeController>();
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bool isPro = themeController.isPro;
    final User? user = _currentUser;

    return NavShell(
      currentIndex: 4,
      title: 'Profile & Settings',
      automaticallyImplyLeading: false,
      body: _loading
          ? _buildLoadingState()
          : ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                // 1. Account & Membership
                _buildUserHeaderCard(palette, user, isPro),
                _sectionLabel('1. Account & Membership'),
                _row(
                  icon: Icons.person_outline_rounded,
                  title: 'Edit Profile',
                  subtitle: 'Name, phone, photo, and family role',
                  onTap: () => Navigator.of(context).pushNamed('/account'),
                ),
                _row(
                  icon: Icons.workspace_premium_outlined,
                  title: 'Subscription & Pro Plan',
                  subtitle: isPro ? 'Sage Pro Active' : 'Free Tier — Tap to Upgrade',
                  iconColor: isPro ? palette.warning : palette.accent,
                  onTap: () => Navigator.of(context).pushNamed('/subscription'),
                ),
                if (_canChangePassword)
                  _row(
                    icon: Icons.lock_reset_rounded,
                    title: 'Password & Security',
                    subtitle: 'Reset password via registered email',
                    onTap: _showChangePasswordDialog,
                  ),

                // 2. Family & Circle
                _sectionLabel('2. Family & Circle'),
                _row(
                  icon: Icons.group_outlined,
                  title: 'Manage Circle',
                  subtitle: 'Circle name, members, and roles',
                  onTap: () => Navigator.of(context).pushNamed('/manage-family'),
                ),
                _row(
                  icon: Icons.mail_outline_rounded,
                  title: 'Invites & Join Codes',
                  subtitle: 'Invite codes and member requests',
                  onTap: () => Navigator.of(context).pushNamed('/manage-invites'),
                ),
                _row(
                  icon: Icons.contact_emergency_outlined,
                  title: 'Emergency Contacts & SOS Setup',
                  subtitle: 'Priority responders and fast emergency actions',
                  onTap: () =>
                      Navigator.of(context).pushNamed('/emergency-contacts'),
                ),

                // 3. Safety & Privacy
                _sectionLabel('3. Safety & Privacy'),
                _toggleRow(
                  icon: Icons.location_on_outlined,
                  title: 'Location Sharing',
                  subtitle: _locationSharing
                      ? 'Sharing live updates with circle'
                      : 'Location sharing is paused',
                  value: _locationSharing,
                  onChanged: _handleLocationSharingToggle,
                ),
                _row(
                  icon: Icons.tune_rounded,
                  title: 'Location Sharing Mode',
                  subtitle: 'Always, Circle Only, or Emergency Only',
                  onTap: _handleLocationModePicker,
                ),
                _toggleRow(
                  icon: Icons.visibility_outlined,
                  title: 'Circle Visibility (Ghost mode)',
                  subtitle: 'Show your avatar on the live circle map',
                  value: _circleVisibility,
                  onChanged: (bool value) async {
                    await _saveBool(_kCircleVisibility, value);
                    if (!mounted) return;
                    setState(() => _circleVisibility = value);
                  },
                ),
                _row(
                  icon: Icons.security_outlined,
                  title: 'Privacy & Data Center',
                  subtitle: 'GDPR consents, retention rules, and JSON/CSV export',
                  onTap: () =>
                      Navigator.of(context).pushNamed('/privacy/dashboard'),
                ),
                _row(
                  icon: Icons.psychology_outlined,
                  title: 'AI Smart Alerts & Routine Insights',
                  subtitle: 'Configure routine learning and smart silence',
                  onTap: () => Navigator.of(context).pushNamed('/settings/ai'),
                ),

                // 4. Notifications & Alerts
                _sectionLabel('4. Notifications & Alerts'),
                _toggleRow(
                  icon: Icons.notifications_active_outlined,
                  title: 'Push Notifications',
                  subtitle: 'Receive real-time circle updates and check-ins',
                  value: _pushNotifications,
                  onChanged: _handlePushNotificationToggle,
                ),
                _toggleRow(
                  icon: Icons.volume_up_outlined,
                  title: 'Sound & Critical Alerts',
                  subtitle: 'Play audible sirens during emergency alerts',
                  value: _alertSounds,
                  onChanged: (bool value) async {
                    await _saveBool(_kAlertSounds, value);
                    if (!mounted) return;
                    setState(() => _alertSounds = value);
                  },
                ),
                _toggleRow(
                  icon: Icons.bedtime_outlined,
                  title: 'Quiet Hours & Sleep Schedule',
                  subtitle: 'Silence non-urgent notifications during sleep',
                  value: _quietHours,
                  onChanged: (bool value) async {
                    await _saveBool(_kQuietHours, value);
                    if (!mounted) return;
                    setState(() => _quietHours = value);
                  },
                ),

                // 5. App Experience & Accessibility
                _sectionLabel('5. App Experience & Accessibility'),
                _toggleRow(
                  icon: Icons.dark_mode_outlined,
                  title: 'Dark Theme',
                  subtitle: isDarkMode ? 'Dark mode enabled' : 'Light mode enabled',
                  value: isDarkMode,
                  onChanged: (bool value) {
                    themeController.setMode(
                      value ? ThemeMode.dark : ThemeMode.light,
                    );
                  },
                ),
                _row(
                  icon: Icons.accessibility_new_rounded,
                  title: 'Sensory & Comfort Controls',
                  subtitle: 'Calm mode, haptic feedback, and reading comfort',
                  onTap: () => Navigator.of(context)
                      .pushNamed('/settings/sensory-controls'),
                ),
                _row(
                  icon: Icons.language_rounded,
                  title: 'App Language',
                  subtitle: _appLanguage,
                  onTap: () async {
                    final String? selected =
                        await showModalBottomSheet<String>(
                      context: context,
                      backgroundColor: palette.surface,
                      shape: const RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                      builder: (BuildContext ctx) {
                        return SafeArea(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ListTile(
                                title: Text(
                                  'English',
                                  style: KinCircleTypography.body14(
                                    color: palette.textPrimary,
                                    weight: _appLanguage == 'English'
                                        ? FontWeight.w700
                                        : FontWeight.normal,
                                  ),
                                ),
                                trailing: _appLanguage == 'English'
                                    ? Icon(Icons.check, color: palette.accent)
                                    : null,
                                onTap: () => Navigator.of(ctx).pop('English'),
                              ),
                              ListTile(
                                title: Text(
                                  'Arabic',
                                  style: KinCircleTypography.body14(
                                    color: palette.textPrimary,
                                    weight: _appLanguage == 'Arabic'
                                        ? FontWeight.w700
                                        : FontWeight.normal,
                                  ),
                                ),
                                trailing: _appLanguage == 'Arabic'
                                    ? Icon(Icons.check, color: palette.accent)
                                    : null,
                                onTap: () => Navigator.of(ctx).pop('Arabic'),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                    if (selected == null) return;
                    await _saveString(_kAppLanguage, selected);
                    if (!mounted) return;
                    setState(() => _appLanguage = selected);
                  },
                ),
                _row(
                  icon: Icons.cleaning_services_outlined,
                  title: 'Storage & Cache',
                  subtitle: 'Safe purge of cached images and temporary files',
                  onTap: _handleSafeClearCache,
                ),

                // 6. Help, Support & Session
                _sectionLabel('6. Help, Support & Session'),
                _row(
                  icon: Icons.help_outline_rounded,
                  title: 'Help Center & FAQs',
                  subtitle: 'Frequently asked questions and guides',
                  onTap: () => Navigator.of(context).pushNamed('/help'),
                ),
                _row(
                  icon: Icons.feedback_outlined,
                  title: 'Send Feedback',
                  subtitle: 'Share suggestions or report an issue',
                  onTap: () => Navigator.of(context).pushNamed('/feedback'),
                ),
                _row(
                  icon: Icons.medical_services_outlined,
                  title: 'Diagnostics & System Health',
                  subtitle: 'View crash diagnostics and telemetry status',
                  onTap: () => Navigator.of(context).pushNamed('/diagnostics'),
                ),
                _row(
                  icon: Icons.policy_outlined,
                  title: 'Privacy Policy & Terms of Service',
                  subtitle: 'Review legal terms and privacy disclosures',
                  onTap: () {
                    showDialog<void>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: palette.surface,
                        title: Text(
                          'Legal & Privacy',
                          style: KinCircleTypography.cardTitle16(
                            color: palette.textPrimary,
                            weight: FontWeight.w700,
                          ),
                        ),
                        content: Text(
                          'KinCircle is committed to your family\'s safety and privacy. Your location data is strictly encrypted and never sold to third parties.',
                          style: KinCircleTypography.body14(
                            color: palette.textMuted,
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: Text(
                              'Close',
                              style: KinCircleTypography.body14(
                                color: palette.accent,
                                weight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                _row(
                  icon: Icons.logout_rounded,
                  title: 'Sign Out',
                  subtitle: 'Disconnect current session',
                  titleColor: palette.error,
                  iconColor: palette.error,
                  onTap: () => _confirmDestructive(
                    title: 'Sign out?',
                    body: 'You can sign back in anytime with your credentials.',
                    onConfirmed: _signOut,
                  ),
                ),

                // Danger zone
                _sectionLabel('Danger Zone', color: palette.error),
                _row(
                  icon: Icons.exit_to_app_rounded,
                  title: 'Leave Family Circle',
                  subtitle: 'Remove yourself from the current circle',
                  iconColor: palette.textMuted,
                  onTap: _handleLeaveFamily,
                ),
                _row(
                  icon: Icons.delete_forever_outlined,
                  title: 'Delete Account',
                  subtitle: 'Permanently delete your account and all history',
                  titleColor: palette.error,
                  iconColor: palette.error,
                  onTap: _handleDeleteAccount,
                ),

                const SizedBox(height: 28),
                Center(
                  child: Column(
                    children: [
                      Image.asset(
                        'assets/icon/kincircle_icon.png',
                        width: 48,
                        height: 48,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'KinCircle',
                        style: KinCircleTypography.body14(
                          color: palette.textPrimary,
                          weight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Version 1.0.0',
                        style: KinCircleTypography.caption12(
                          color: palette.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildLoadingState() {
    final palette = KinCirclePalette.of(context);
    return Shimmer.fromColors(
      baseColor: palette.surfaceAlt,
      highlightColor: palette.border,
      child: ListView.builder(
        itemCount: 8,
        itemBuilder: (_, int index) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            height: 64,
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(14),
            ),
          );
        },
      ),
    );
  }
}

