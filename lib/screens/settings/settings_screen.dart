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
  bool _fabTipDisabled = false;
  bool _privacyLoaded = false;
  bool _exportingData = false;

  @override
  void initState() {
    super.initState();
    _smartAlertsEnabled = _rc.smartAlertsEnabled;
    _mlAlerts = _rc.mlAlertsEnabled;
    ConsentService().isConsentGiven().then((v) {
      if (mounted) setState(() => _consentGiven = v);
    });
    _loadFabTipPref();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initPrivacySettings());
  }

  Future<void> _loadFabTipPref() async {
    try {
      final p = await SharedPreferences.getInstance();
      setState(() {
        _fabTipDisabled = p.getBool('fab_actions_label_disabled') ?? false;
      });
    } catch (_) {}
  }

  Future<void> _setFabTipDisabled(bool disabled) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool('fab_actions_label_disabled', disabled);
    } catch (_) {}
  }

  Future<void> _resetFabTipSeen() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool('fab_actions_label_seen', false);
    } catch (_) {}
  }

  Future<void> _initPrivacySettings() async {
    try {
      final String? userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;
      final privacy = context.read<PrivacyControlsService>();
      await privacy.loadPrivacySettings(userId);
      if (!mounted) return;
      setState(() => _privacyLoaded = true);
    } catch (_) {}
  }

  Future<void> _quickExportData() async {
    setState(() => _exportingData = true);
    try {
      final file = await DataExportService.exportUserData(format: 'json');
      if (!mounted) return;
      await DataExportService.shareExport(file);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _exportingData = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          IconButton(
            tooltip: 'Help',
            icon: const Icon(Icons.help_outline),
            onPressed: () => Navigator.of(context).pushNamed('/help'),
          ),
        ],
      ),
      body: ListView(
        children: [
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text('Appearance',
                style: Theme.of(context).textTheme.titleSmall),
          ),
          Consumer<ThemeController>(
            builder: (context, theme, _) {
              final selected = theme.mode;
              return Column(
                children: [
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    title: const Text('Theme'),
                    trailing: DropdownButton<ThemeMode>(
                      value: selected,
                      items: const [
                        DropdownMenuItem(
                          value: ThemeMode.system,
                          child: Text('System'),
                        ),
                        DropdownMenuItem(
                          value: ThemeMode.light,
                          child: Text('Light'),
                        ),
                        DropdownMenuItem(
                          value: ThemeMode.dark,
                          child: Text('Dark'),
                        ),
                      ],
                      onChanged: (mode) {
                        if (mode != null) theme.setMode(mode);
                      },
                    ),
                  ),
                  SwitchListTile(
                    title: const Text('Use Pro Accent (Preview)'),
                    subtitle:
                        const Text('Shows premium accent color when active'),
                    value: theme.isPro,
                    onChanged: (v) => theme.setPro(v),
                  ),
                ],
              );
            },
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text('Privacy & Security',
                style: Theme.of(context).textTheme.titleSmall),
          ),
          Consumer<PrivacyControlsService>(
            builder: (context, privacy, _) {
              final bool hasScore = _privacyLoaded && privacy.isLoaded;
              final int score = hasScore ? privacy.calculatePrivacyScore() : 0;
              final Color chipColor = score >= 80
                  ? Colors.green
                  : score >= 60
                      ? Colors.orange
                      : Colors.red;
              return Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.privacy_tip_outlined),
                    title: const Text('Privacy & Data'),
                    subtitle: const Text(
                        'Control encryption, consent, and GDPR exports'),
                    trailing: hasScore
                        ? Chip(
                            label: Text('$score'),
                            avatar: const Icon(Icons.shield,
                                size: 16, color: Colors.white),
                            backgroundColor: chipColor,
                            labelStyle: const TextStyle(color: Colors.white),
                          )
                        : const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context)
                        .pushNamed('/privacy/dashboard'),
                  ),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextButton.icon(
                            icon: _exportingData
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.download),
                            label: Text(
                                _exportingData ? 'Exporting…' : 'Quick Export'),
                            onPressed:
                                _exportingData ? null : () => _quickExportData(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton(
                          onPressed: () => Navigator.of(context)
                              .pushNamed('/privacy/dashboard'),
                          child: const Text('Manage'),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text('Tips & Hints',
                style: Theme.of(context).textTheme.titleSmall),
          ),
          SwitchListTile(
            title: const Text('Show “Actions” Tip'),
            subtitle: const Text(
                'Show the small hint label near the action button when collapsed'),
            value: !_fabTipDisabled,
            onChanged: (val) async {
              setState(() => _fabTipDisabled = !val);
              await _setFabTipDisabled(!val);
            },
          ),
          ListTile(
            leading: const Icon(Icons.refresh),
            title: const Text('Reset Tip Seen State'),
            subtitle: const Text('Reshow the tip even if it was faded before'),
            onTap: () async {
              final messenger = ScaffoldMessenger.of(context);
              await _resetFabTipSeen();
              if (!mounted) return;
              messenger.showSnackBar(
                const SnackBar(
                    content: Text(
                        'Tip will be shown next time the sheet is collapsed.')),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('Smart Alerts',
                style: Theme.of(context).textTheme.titleSmall),
          ),
          SwitchListTile(
            title: const Text('Enable Smart Alerts'),
            value: _smartAlertsEnabled ?? false,
            onChanged: (val) async {
              setState(() => _smartAlertsEnabled = val);
              await _rc.setSmartAlertsEnabled(val);
            },
          ),
          SwitchListTile(
            title: const Text('Enable ML-Based Alerts'),
            subtitle: (_consentGiven ?? false)
                ? null
                : const Text('Requires consent. Complete consent to enable.'),
            value: _mlAlerts ?? false,
            onChanged: (_consentGiven ?? false)
                ? (val) async {
                    setState(() => _mlAlerts = val);
                    await _rc.setMlAlertsEnabled(val);
                  }
                : null,
          ),
          if (!(_consentGiven ?? false))
            ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: const Text('Complete Smart Alerts Consent'),
              subtitle: const Text('Learn how Smart Alerts work and opt in.'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final nav = Navigator.of(context);
                final agreed = await nav.push<bool>(
                  MaterialPageRoute(builder: (_) => const AiConsentScreen()),
                );
                if (agreed == true && mounted) {
                  setState(() => _consentGiven = true);
                }
              },
            ),
          const Divider(),
          ListTile(
            title: const Text('Diagnostics'),
            subtitle: const Text('Check crashes and send a report'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).pushNamed('/diagnostics'),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text('Accessibility',
                style: Theme.of(context).textTheme.titleSmall),
          ),
          Consumer<AgeDetectionService>(
            builder: (context, ageDetection, _) {
              return Column(
                children: [
                  // Elderly UI Mode is now automatically handled by age input in Sensory Controls
                  ListTile(
                    leading: const Icon(Icons.support_agent),
                    title: const Text('Remote Tech Support'),
                    subtitle: const Text('Get help from family members'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(context).pushNamed('/support/remote');
                    },
                  ),
                  Consumer<FeatureUnlockService>(
                    builder: (context, featureUnlock, _) {
                      final progress = featureUnlock.progressPercentage;
                      final totalScore = featureUnlock.totalScore;
                      final maxScore = featureUnlock.maxScore;

                      return ListTile(
                        leading: const Icon(Icons.emoji_events),
                        title: const Text('Feature Progress'),
                        subtitle: Text(
                          '$totalScore / $maxScore points - ${(progress * 100).toInt()}% unlocked',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          _showFeatureProgressDialog(context, featureUnlock);
                        },
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.spa),
                    title: const Text('Sensory & Comfort'),
                    subtitle: const Text('Accessibility for neurodivergent users'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(context).pushNamed('/settings/sensory-controls');
                    },
                  ),
                  Consumer<CompanionService>(
                    builder: (context, companion, _) {
                      final hasActiveCompanion =
                          companion.relationshipScore > 0 ||
                              companion.recentMessages.isNotEmpty;
                      return ListTile(
                        leading: const Icon(Icons.favorite),
                        title: const Text('Your Companion'),
                        subtitle: Text(
                          hasActiveCompanion
                              ? '${companion.profile.name} - Bond: ${companion.relationshipScore}/100'
                              : 'Choose your AI companion',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.of(context).pushNamed('/companion/select');
                        },
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.auto_awesome),
                    title: const Text('Community Moments'),
                    subtitle: const Text('Share and celebrate with others'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(context).pushNamed('/community/feed');
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.analytics),
                    title: const Text('Wellbeing & Analytics'),
                    subtitle: const Text('Family health insights and trends'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(context).pushNamed('/analytics/wellbeing');
                    },
                  ),
                ],
              );
            },
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child:
                Text('Account', style: Theme.of(context).textTheme.titleSmall),
          ),
          ListTile(
            leading: const Icon(Icons.manage_accounts_outlined),
            title: const Text('Account & Profile'),
            subtitle: Text(AuthService().user?.email ??
                'View and edit your account details'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).pushNamed('/account');
            },
          ),
          ListTile(
            leading: const Icon(Icons.family_restroom),
            title: const Text('Manage Family'),
            subtitle: const Text('Add or remove family members'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).pushNamed('/manage-family');
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sign Out'),
            onTap: () async {
              final nav = Navigator.of(context);
              await AuthService().signOut();
              if (!mounted) return;
              nav.pushNamedAndRemoveUntil('/welcome', (route) => false);
            },
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text('Subscription',
                style: Theme.of(context).textTheme.titleSmall),
          ),
          ListTile(
            leading: const Icon(Icons.workspace_premium_outlined),
            title: const Text('Manage Subscription'),
            subtitle: const Text('Plans, billing, and benefits'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).pushNamed('/subscription');
            },
          ),
          const Divider(),
          ListTile(
            title: const Text('AI & Smart Features'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AiSettingsScreen()),
              );
            },
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text('Safety & Emergency',
                style: Theme.of(context).textTheme.titleSmall),
          ),
          ListTile(
            leading: Icon(Icons.emergency, color: Colors.red.shade700),
            title: const Text('🚨 Emergency Contacts'),
            subtitle: const Text('Crisis coordination & response'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).pushNamed('/emergency-contacts');
            },
          ),
          const Divider(),
          ListTile(
            title: const Text('Manage Invites (Debug)'),
            leading: const Icon(Icons.bug_report_outlined),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ManageInvitesScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showFeatureProgressDialog(
      BuildContext context, FeatureUnlockService featureUnlock) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Feature Unlock Progress'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total Score: ${featureUnlock.totalScore} / ${featureUnlock.maxScore}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: featureUnlock.progressPercentage,
                  backgroundColor: Colors.grey.shade300,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).primaryColor,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Unlocked Features:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ...featureUnlock.getUnlockedFeatures().map((featureId) {
                  final config = featureUnlock.getFeatureConfig(featureId);
                  return ListTile(
                    leading: Text(
                      config?.icon ?? '✅',
                      style: const TextStyle(fontSize: 24),
                    ),
                    title: Text(config?.name ?? featureId.name),
                    subtitle: Text(config?.description ?? ''),
                    dense: true,
                  );
                }),
                const SizedBox(height: 16),
                const Text(
                  'Locked Features:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ...featureUnlock.getLockedFeatures().map((featureId) {
                  final config = featureUnlock.getFeatureConfig(featureId);
                  final state = featureUnlock.getFeatureState(featureId);
                  return ListTile(
                    leading: const Text(
                      '🔒',
                      style: TextStyle(fontSize: 24),
                    ),
                    title: Text(config?.name ?? featureId.name),
                    subtitle: Text(
                      '${state?.progressCount ?? 0} / ${config?.threshold ?? 0} - ${config?.description ?? ''}',
                    ),
                    dense: true,
                  );
                }),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
}
