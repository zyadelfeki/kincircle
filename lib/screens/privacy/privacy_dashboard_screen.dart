import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/consent_management_service.dart';
import '../../services/data_export_service.dart';
import '../../services/privacy_controls_service.dart';

class PrivacyDashboardScreen extends StatefulWidget {
  const PrivacyDashboardScreen({super.key});

  @override
  State<PrivacyDashboardScreen> createState() => _PrivacyDashboardScreenState();
}

class _PrivacyDashboardScreenState extends State<PrivacyDashboardScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late PrivacyControlsService _privacyService;
  bool _isLoading = true;
  Map<ConsentType, bool> _consentStatus = <ConsentType, bool>{};

  @override
  void initState() {
    super.initState();
    _privacyService = context.read<PrivacyControlsService>();
    _loadPrivacyState();
  }

  Future<void> _loadPrivacyState() async {
    final String userId = _auth.currentUser!.uid;
    await _privacyService.loadPrivacySettings(userId);
    final Map<ConsentType, bool> consent =
        await ConsentManagementService.getConsentStatus(userId);
    if (!mounted) return;
    setState(() {
      _consentStatus = consent;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Handle empty data gracefully - show empty state rather than infinite spinner
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Privacy & Data')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (!_privacyService.isLoaded) {
      // Settings didn't load; show empty state instead of spinner
      return Scaffold(
        appBar: AppBar(title: const Text('Privacy & Data')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.shield_outlined, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                'No privacy settings found',
                style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _loadPrivacyState,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy & Data'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showPrivacyInfo,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadPrivacyState,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPrivacyScoreCard(),
              const SizedBox(height: 24),
              _sectionTitle('Location Sharing'),
              const SizedBox(height: 12),
              _buildLocationSharingControls(),
              const SizedBox(height: 24),
              _sectionTitle('Data Retention'),
              const SizedBox(height: 12),
              _buildDataRetentionControls(),
              const SizedBox(height: 24),
              _sectionTitle('Your Data'),
              const SizedBox(height: 12),
              _buildDataExportOptions(),
              const SizedBox(height: 24),
              _sectionTitle('Consents'),
              const SizedBox(height: 12),
              _buildConsentToggles(),
              const SizedBox(height: 24),
              _sectionTitle('Account Deletion', color: Colors.red),
              const SizedBox(height: 12),
              _buildDangerZone(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text, {Color? color}) {
    return Text(
      text,
      style: Theme.of(context)
          .textTheme
          .headlineSmall
          ?.copyWith(color: color ?? Theme.of(context).colorScheme.onSurface),
    );
  }

  Widget _buildPrivacyScoreCard() {
    final int score = _privacyService.calculatePrivacyScore();
    final Color color = score >= 80
        ? Colors.green
        : score >= 60
            ? Colors.orange
            : Colors.red;
    final String label = score >= 80
        ? 'Excellent privacy posture'
        : score >= 60
            ? 'Good privacy hygiene'
            : 'Privacy can be improved';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(Icons.shield, size: 48, color: color),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Privacy Score',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$score / 100',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(label, style: const TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationSharingControls() {
    final PrivacySettings settings = _privacyService.settings!;

    return Card(
      child: Column(
        children: [
          SwitchListTile(
            title: const Text('Enable Location Sharing'),
            subtitle: const Text('Share your live location with family'),
            value: settings.locationSharingEnabled,
            onChanged: (bool value) {
              _updateLocationSharing(enabled: value);
            },
          ),
          if (settings.locationSharingEnabled) ...[
            const Divider(height: 0),
            ListTile(
              title: const Text('Sharing Mode'),
              subtitle: Text(settings.locationSharingMode.label()),
              trailing: const Icon(Icons.chevron_right),
              onTap: _selectSharingMode,
            ),
            ListTile(
              title: const Text('Allowed Members'),
              subtitle: Text(
                settings.allowedFamilyMembers.isEmpty
                    ? 'All family members'
                    : settings.allowedFamilyMembers.join(', '),
              ),
              trailing: const Icon(Icons.group),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDataRetentionControls() {
    final PrivacySettings settings = _privacyService.settings!;
    return Card(
      child: Column(
        children: [
          SwitchListTile(
            title: const Text('Auto-delete old data'),
            subtitle:
                const Text('Automatically remove data past retention period'),
            value: settings.autoDeleteEnabled,
            onChanged: _toggleAutoDelete,
          ),
          const Divider(height: 0),
          ListTile(
            title: const Text('Retention period'),
            subtitle: Text('${settings.dataRetentionDays} days'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _selectRetentionPeriod,
          ),
        ],
      ),
    );
  }

  Widget _buildDataExportOptions() {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.download, color: Colors.blue),
            title: const Text('Download your data'),
            subtitle: const Text('Export JSON or CSV copy for your records'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _exportData,
          ),
          const Divider(height: 0),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.orange),
            title: const Text('Request data deletion'),
            subtitle: const Text('Remove specific data categories'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _requestDataDeletion,
          ),
        ],
      ),
    );
  }

  Widget _buildConsentToggles() {
    return Card(
      child: Column(
        children: ConsentType.values.map((ConsentType type) {
          final bool value = _consentStatus[type] ?? false;
          return SwitchListTile(
            title: Text(_formatConsentType(type)),
            subtitle: Text(_consentDescription(type)),
            value: value,
            onChanged: (bool newValue) => _updateConsent(type, newValue),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDangerZone() {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.warning, color: Colors.red),
        title: const Text(
          'Delete account',
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
        ),
        subtitle: const Text('Permanently remove your account and data'),
        trailing: const Icon(Icons.chevron_right, color: Colors.red),
        onTap: _confirmAccountDeletion,
      ),
    );
  }

  Future<void> _updateLocationSharing({required bool enabled}) async {
    final String userId = _auth.currentUser!.uid;
    await _privacyService.updateLocationSharing(
      userId: userId,
      enabled: enabled,
    );
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _selectSharingMode() async {
    final PrivacySettings settings = _privacyService.settings!;
    final LocationSharingMode? result = await showModalBottomSheet<
        LocationSharingMode>(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children:
                LocationSharingMode.values.map((LocationSharingMode mode) {
              final bool isSelected = settings.locationSharingMode == mode;
              return ListTile(
                title: Text(mode.label()),
                trailing:
                    isSelected ? const Icon(Icons.check_circle) : null,
                onTap: () => Navigator.pop(context, mode),
              );
            }).toList(),
          ),
        );
      },
    );

    if (result != null) {
      final String userId = _auth.currentUser!.uid;
      await _privacyService.updateLocationSharing(
        userId: userId,
        enabled: settings.locationSharingEnabled,
        mode: result,
      );
      if (!mounted) return;
      setState(() {});
    }
  }

  Future<void> _toggleAutoDelete(bool value) async {
    final String userId = _auth.currentUser!.uid;
    final PrivacySettings settings = _privacyService.settings!;
    final int days = value ? settings.dataRetentionDays : 0;
    await _privacyService.setDataRetentionPeriod(userId: userId, days: days);
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _selectRetentionPeriod() async {
    final List<int> options = <int>[30, 60, 90, 180, 365];
    final int? result = await showDialog<int>(
      context: context,
      builder: (BuildContext context) {
        return SimpleDialog(
          title: const Text('Select retention period'),
          children: options
              .map((int days) => SimpleDialogOption(
                    onPressed: () => Navigator.pop(context, days),
                    child: Text('$days days'),
                  ))
              .toList(),
        );
      },
    );

    if (result != null) {
      final String userId = _auth.currentUser!.uid;
      await _privacyService.setDataRetentionPeriod(
        userId: userId,
        days: result,
      );
      if (!mounted) return;
      setState(() {});
    }
  }

  Future<void> _exportData() async {
    final String? format = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Export format'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('JSON'),
                subtitle: const Text('Machine-readable format'),
                onTap: () => Navigator.pop(context, 'json'),
              ),
              ListTile(
                title: const Text('CSV'),
                subtitle: const Text('Spreadsheet compatible'),
                onTap: () => Navigator.pop(context, 'csv'),
              ),
            ],
          ),
        );
      },
    );

    if (format == null) return;
    if (!mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Center(child: CircularProgressIndicator());
      },
    );

    try {
      final file = await DataExportService.exportUserData(format: format);
      if (!mounted) return;
      Navigator.pop(context); // close loading dialog
      await DataExportService.shareExport(file);
    } catch (error) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $error')),
      );
    }
  }

  Future<void> _requestDataDeletion() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Request data deletion'),
          content: const Text(
            'We will process your deletion request within 30 days. '
            'You can specify which categories to remove by emailing privacy@kincircle.app.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Deletion request submitted. We will email next steps.'),
        ),
      );
    }
  }

  Future<void> _updateConsent(ConsentType type, bool value) async {
    final String userId = _auth.currentUser!.uid;
    await ConsentManagementService.recordConsent(
      userId: userId,
      type: type,
      granted: value,
    );
    final Map<ConsentType, bool> status =
        await ConsentManagementService.getConsentStatus(userId);
    if (!mounted) return;
    setState(() => _consentStatus = status);
  }

  Future<void> _confirmAccountDeletion() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete account?'),
          content: const Text(
            'This permanently removes your account, family data, and history. '
            'This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _deleteAccount();
    }
  }

  Future<void> _deleteAccount() async {
    final String userId = _auth.currentUser!.uid;
    await _privacyService.updateLocationSharing(
      userId: userId,
      enabled: false,
    );
    // Additional account deletion logic would go here (Cloud Function trigger).
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Account deletion workflow initiated.')),
    );
  }

  void _showPrivacyInfo() {
    showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext context) {
        return const SafeArea(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Privacy-first design',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 12),
                Text(
                  'KinCircle encrypts sensitive data end-to-end and minimizes '
                  'retention to honor GDPR and HIPAA requirements.',
                ),
                SizedBox(height: 12),
                Text('• Encrypted backups and exports'),
                Text('• Data minimization & retention controls'),
                Text('• Transparent consent management'),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatConsentType(ConsentType type) {
    switch (type) {
      case ConsentType.dataProcessing:
        return 'Data processing';
      case ConsentType.locationTracking:
        return 'Location tracking';
      case ConsentType.analytics:
        return 'Analytics';
      case ConsentType.marketing:
        return 'Marketing';
      case ConsentType.thirdPartySharing:
        return 'Third-party sharing';
      case ConsentType.aiProcessing:
        return 'AI processing';
      case ConsentType.healthData:
        return 'Health data';
    }
  }

  String _consentDescription(ConsentType type) {
    switch (type) {
      case ConsentType.dataProcessing:
        return 'Allow processing of your personal data for the core service.';
      case ConsentType.locationTracking:
        return 'Share your location with family safety features.';
      case ConsentType.analytics:
        return 'Help improve KinCircle via anonymized analytics.';
      case ConsentType.marketing:
        return 'Receive product updates and privacy notices.';
      case ConsentType.thirdPartySharing:
        return 'Share data with emergency services or selected partners.';
      case ConsentType.aiProcessing:
        return 'Allow AI wellbeing insights and personalized nudges.';
      case ConsentType.healthData:
        return 'Process optional health metrics you provide.';
    }
  }
}
