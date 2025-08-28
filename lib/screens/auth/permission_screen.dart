import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionScreen extends StatefulWidget {
  const PermissionScreen({super.key});

  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen> {
  bool _requesting = false;
  bool _locationGranted = false;
  bool _askedNotifications = false;
  String? _notifStatusLabel;

  Future<void> _requestLocation() async {
    setState(() => _requesting = true);
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) {
        await Geolocator.openAppSettings();
      }
      setState(() => _locationGranted = perm == LocationPermission.always || perm == LocationPermission.whileInUse);
    } catch (e) {
      if (kDebugMode) debugPrint('Location request failed: $e');
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  Future<void> _requestNotifications() async {
    final status = await Permission.notification.status;
    if (status.isGranted) {
      setState(() {
        _askedNotifications = true;
        _notifStatusLabel = 'Enabled';
      });
      return;
    }
    final res = await Permission.notification.request();
    if (res.isPermanentlyDenied) {
      await openAppSettings();
    }
    setState(() {
      _askedNotifications = res.isGranted || res.isLimited;
      _notifStatusLabel = res.isGranted
          ? 'Enabled'
          : res.isPermanentlyDenied
              ? 'Denied (settings)'
              : 'Denied';
    });
  }

  Future<void> _continue() async {
    if (!_locationGranted) {
      await _requestLocation();
    }
    if (!_askedNotifications) {
      await _requestNotifications();
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/dashboard');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Enable Permissions')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Power key features with two quick permissions', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text('• Location powers the family map and driving safety.\n• Notifications keep you informed about important updates.',
                  style: theme.textTheme.bodyMedium),
              const SizedBox(height: 24),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.location_on),
                  title: const Text('Location'),
                  subtitle: Text(_locationGranted ? 'Enabled' : 'Needed for map and safety features'),
                  trailing: _locationGranted
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : FilledButton(
                          onPressed: _requesting ? null : _requestLocation,
                          child: const Text('Allow'),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.notifications_active),
                  title: const Text('Notifications'),
                  subtitle: Text(_notifStatusLabel ?? (_askedNotifications ? 'Enabled' : 'Recommended for timely alerts')),
                  trailing: _askedNotifications
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : FilledButton(
                          onPressed: _requestNotifications,
                          child: const Text('Enable'),
                        ),
                ),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _continue,
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Continue'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
