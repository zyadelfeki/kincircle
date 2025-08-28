import 'package:flutter/material.dart';
import '../../services/remote_config_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/auth_service.dart';
import '../settings/ai_consent_screen.dart';
import '../../services/consent_service.dart';
import 'ai_settings_screen.dart';
import '../family/manage_invites_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _smartAlertsEnabled = _rc.smartAlertsEnabled;
    _mlAlerts = _rc.mlAlertsEnabled;
    ConsentService().isConsentGiven().then((v) {
      if (mounted) setState(() => _consentGiven = v);
    });
    _loadFabTipPref();
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
            child: Text('Tips & Hints', style: Theme.of(context).textTheme.titleSmall),
          ),
          SwitchListTile(
            title: const Text('Show “Actions” Tip'),
            subtitle: const Text('Show the small hint label near the action button when collapsed'),
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
              await _resetFabTipSeen();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Tip will be shown next time the sheet is collapsed.')),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('Smart Alerts', style: Theme.of(context).textTheme.titleSmall),
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
                final agreed = await Navigator.of(context).push<bool>(
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
            child: Text('Account', style: Theme.of(context).textTheme.titleSmall),
          ),
          ListTile(
            leading: const Icon(Icons.manage_accounts_outlined),
            title: const Text('Account & Profile'),
            subtitle: Text(AuthService().user?.email ?? 'View and edit your account details'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // Placeholder: navigate when Account screen exists
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Account screen coming soon')),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sign Out'),
            onTap: () async {
              await AuthService().signOut();
              if (!mounted) return;
              Navigator.of(context).popUntil((r) => r.isFirst);
            },
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text('Subscription', style: Theme.of(context).textTheme.titleSmall),
          ),
          ListTile(
            leading: const Icon(Icons.workspace_premium_outlined),
            title: const Text('Manage Subscription'),
            subtitle: const Text('Plans, billing, and benefits'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Subscription management coming soon')),
              );
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
}
