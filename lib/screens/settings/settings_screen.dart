import 'package:flutter/material.dart';
import '../../services/remote_config_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/auth_service.dart';
import '../settings/ai_consent_screen.dart';
import '../../services/consent_service.dart';
import 'ai_settings_screen.dart';
import '../family/manage_invites_screen.dart';
import '../../services/theme_controller.dart';
import 'package:provider/provider.dart';
import '../../services/age_detection_service.dart';
import '../../services/feature_unlock_service.dart';
import '../../services/companion_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/privacy_controls_service.dart';
import '../../services/data_export_service.dart';

/// Redesigned Settings Screen - Clean, organized, intuitive
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final RemoteConfigService _rc = RemoteConfigService();
  bool? _smartAlertsEnabled;
  bool? _mlAlerts;
  bool? _consentGiven;
  bool _privacyLoaded = false;

  @override
  void initState() {
    super.initState();
    _smartAlertsEnabled = _rc.smartAlertsEnabled;
    _mlAlerts = _rc.mlAlertsEnabled;
    ConsentService().isConsentGiven().then((v) {
      if (mounted) setState(() => _consentGiven = v);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _initPrivacySettings());
  }

  Future<void> _initPrivacySettings() async {
    try {
      final String? userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;
      final privacy = context.read<PrivacyControlsService>();
      await privacy.loadPrivacySettings(userId);
      if (!mounted) return;
      setState(() => _privacyLoaded = true);
    } catch (_) {
      if (mounted) setState(() => _privacyLoaded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // Profile Card at top
          _buildProfileCard(user),
          const SizedBox(height: 16),
          
          // SECTION: Family & Safety
          _buildSectionHeader('Family & Safety', Icons.family_restroom),
          _buildSettingsTile(
            icon: Icons.group,
            title: 'Manage Family',
            subtitle: 'Add, remove, and manage family members',
            onTap: () => Navigator.of(context).pushNamed('/manage-family'),
          ),
          _buildSettingsTile(
            icon: Icons.emergency,
            iconColor: Colors.red,
            title: 'Emergency Contacts',
            subtitle: 'Crisis coordination & SOS settings',
            onTap: () => Navigator.of(context).pushNamed('/emergency-contacts'),
          ),
          _buildSettingsTile(
            icon: Icons.analytics_outlined,
            title: 'Wellbeing Dashboard',
            subtitle: 'Family health insights and AI recommendations',
            onTap: () => Navigator.of(context).pushNamed('/analytics/wellbeing'),
          ),
          
          const SizedBox(height: 8),
          
          // SECTION: Privacy & Security
          _buildSectionHeader('Privacy & Security', Icons.shield_outlined),
          Consumer<PrivacyControlsService>(
            builder: (context, privacy, _) {
              final int score = _privacyLoaded && privacy.isLoaded 
                  ? privacy.calculatePrivacyScore() 
                  : 0;
              return _buildSettingsTile(
                icon: Icons.privacy_tip_outlined,
                title: 'Privacy Controls',
                subtitle: 'Encryption, consent, and data management',
                trailing: _privacyLoaded 
                    ? _buildScoreBadge(score)
                    : const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
                onTap: () => Navigator.of(context).pushNamed('/privacy/dashboard'),
              );
            },
          ),
          
          const SizedBox(height: 8),
          
          // SECTION: Appearance
          _buildSectionHeader('Appearance', Icons.palette_outlined),
          Consumer<ThemeController>(
            builder: (context, theme, _) {
              return Column(
                children: [
                  _buildSettingsTile(
                    icon: Icons.dark_mode_outlined,
                    title: 'Theme',
                    subtitle: theme.mode == ThemeMode.system 
                        ? 'System default' 
                        : theme.mode == ThemeMode.dark ? 'Dark' : 'Light',
                    onTap: () => _showThemePicker(theme),
                  ),
                ],
              );
            },
          ),
          
          const SizedBox(height: 8),
          
          // SECTION: Accessibility
          _buildSectionHeader('Accessibility', Icons.accessibility_new),
          _buildSettingsTile(
            icon: Icons.spa_outlined,
            title: 'Sensory & Comfort',
            subtitle: 'Neurodivergent-friendly settings',
            onTap: () => Navigator.of(context).pushNamed('/settings/sensory-controls'),
          ),
          _buildSettingsTile(
            icon: Icons.support_agent,
            title: 'Remote Tech Support',
            subtitle: 'Get help from family members',
            onTap: () => Navigator.of(context).pushNamed('/support/remote'),
          ),
          Consumer<CompanionService>(
            builder: (context, companion, _) {
              return _buildSettingsTile(
                icon: Icons.favorite_outline,
                title: 'AI Companion',
                subtitle: companion.relationshipScore > 0 
                    ? '${companion.profile.name} • Bond: ${companion.relationshipScore}/100'
                    : 'Choose your supportive companion',
                onTap: () => Navigator.of(context).pushNamed('/companion/select'),
              );
            },
          ),
          
          const SizedBox(height: 8),
          
          // SECTION: Smart Features
          _buildSectionHeader('Smart Features', Icons.auto_awesome),
          SwitchListTile(
            secondary: const Icon(Icons.notifications_active_outlined),
            title: const Text('Smart Alerts'),
            subtitle: const Text('AI-powered family notifications'),
            value: _smartAlertsEnabled ?? false,
            onChanged: (val) async {
              setState(() => _smartAlertsEnabled = val);
              await _rc.setSmartAlertsEnabled(val);
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.psychology_outlined),
            title: const Text('ML-Based Alerts'),
            subtitle: Text((_consentGiven ?? false) 
                ? 'Advanced pattern detection' 
                : 'Requires consent'),
            value: _mlAlerts ?? false,
            onChanged: (_consentGiven ?? false)
                ? (val) async {
                    setState(() => _mlAlerts = val);
                    await _rc.setMlAlertsEnabled(val);
                  }
                : null,
          ),
          if (!(_consentGiven ?? false))
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: OutlinedButton.icon(
                onPressed: () async {
                  final agreed = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(builder: (_) => const AiConsentScreen()),
                  );
                  if (agreed == true && mounted) {
                    setState(() => _consentGiven = true);
                  }
                },
                icon: const Icon(Icons.verified_user),
                label: const Text('Complete AI Consent'),
              ),
            ),
          _buildSettingsTile(
            icon: Icons.tune,
            title: 'AI Settings',
            subtitle: 'Fine-tune smart feature behavior',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AiSettingsScreen()),
            ),
          ),
          
          const SizedBox(height: 8),
          
          // SECTION: Account
          _buildSectionHeader('Account', Icons.person_outline),
          _buildSettingsTile(
            icon: Icons.manage_accounts,
            title: 'Profile Settings',
            subtitle: user?.email ?? 'Manage your account',
            onTap: () => Navigator.of(context).pushNamed('/account'),
          ),
          _buildSettingsTile(
            icon: Icons.workspace_premium,
            title: 'Subscription',
            subtitle: 'Plans, billing, and benefits',
            onTap: () => Navigator.of(context).pushNamed('/subscription'),
          ),
          _buildSettingsTile(
            icon: Icons.logout,
            iconColor: Colors.red,
            title: 'Sign Out',
            onTap: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Sign Out?'),
                  content: const Text('Are you sure you want to sign out?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Sign Out'),
                    ),
                  ],
                ),
              );
              if (confirmed == true && mounted) {
                await AuthService().signOut();
                if (mounted) {
                  Navigator.of(context).pushNamedAndRemoveUntil('/welcome', (route) => false);
                }
              }
            },
          ),
          
          const SizedBox(height: 8),
          
          // SECTION: Support
          _buildSectionHeader('Support', Icons.help_outline),
          _buildSettingsTile(
            icon: Icons.bug_report_outlined,
            title: 'Diagnostics',
            subtitle: 'Debug info and crash reports',
            onTap: () => Navigator.of(context).pushNamed('/diagnostics'),
          ),
          _buildSettingsTile(
            icon: Icons.help,
            title: 'Help Center',
            onTap: () => Navigator.of(context).pushNamed('/help'),
          ),
          
          const SizedBox(height: 24),
          
          // App version
          Center(
            child: Text(
              'KinCircle v1.0.0',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildProfileCard(User? user) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: InkWell(
        onTap: () => Navigator.of(context).pushNamed('/account'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundImage: user?.photoURL != null 
                    ? NetworkImage(user!.photoURL!) 
                    : null,
                child: user?.photoURL == null 
                    ? Text(
                        (user?.displayName ?? user?.email ?? 'U')[0].toUpperCase(),
                        style: const TextStyle(fontSize: 24),
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.displayName ?? 'Set up your profile',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user?.email ?? '',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final headerColor = isDark 
        ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.9)
        : Theme.of(context).primaryColor;
    
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: headerColor),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: headerColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Color? iconColor,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle) : null,
      trailing: trailing ?? const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }

  Widget _buildScoreBadge(int score) {
    final Color color = score >= 80 
        ? Colors.green 
        : score >= 60 
            ? Colors.orange 
            : Colors.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shield, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            '$score',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  void _showThemePicker(ThemeController theme) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            const Text(
              'Choose Theme',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.brightness_auto),
              title: const Text('System Default'),
              trailing: theme.mode == ThemeMode.system 
                  ? const Icon(Icons.check, color: Colors.green) 
                  : null,
              onTap: () {
                theme.setMode(ThemeMode.system);
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.light_mode),
              title: const Text('Light'),
              trailing: theme.mode == ThemeMode.light 
                  ? const Icon(Icons.check, color: Colors.green) 
                  : null,
              onTap: () {
                theme.setMode(ThemeMode.light);
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.dark_mode),
              title: const Text('Dark'),
              trailing: theme.mode == ThemeMode.dark 
                  ? const Icon(Icons.check, color: Colors.green) 
                  : null,
              onTap: () {
                theme.setMode(ThemeMode.dark);
                Navigator.pop(ctx);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
