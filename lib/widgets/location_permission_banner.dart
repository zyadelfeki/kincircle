import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../design/kincircle_screen_tokens.dart';

class LocationPermissionBanner extends StatefulWidget {
  const LocationPermissionBanner({super.key, this.onPermissionGranted});

  final VoidCallback? onPermissionGranted;

  @override
  State<LocationPermissionBanner> createState() =>
      _LocationPermissionBannerState();
}

class _LocationPermissionBannerState extends State<LocationPermissionBanner>
    with WidgetsBindingObserver {
  bool _isDenied = false;
  bool _isPermanentlyDenied = false;
  bool _isServiceDisabled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermission();
    }
  }

  Future<void> _checkPermission() async {
    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() {
            _isServiceDisabled = true;
            _isDenied = true;
            _isPermanentlyDenied = false;
          });
        }
        return;
      }

      final LocationPermission permission =
          await Geolocator.checkPermission();
      if (!mounted) return;

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _isServiceDisabled = false;
          _isDenied = true;
          _isPermanentlyDenied = true;
        });
      } else if (permission == LocationPermission.denied) {
        setState(() {
          _isServiceDisabled = false;
          _isDenied = true;
          _isPermanentlyDenied = false;
        });
      } else {
        final wasDenied = _isDenied;
        setState(() {
          _isServiceDisabled = false;
          _isDenied = false;
          _isPermanentlyDenied = false;
        });
        if (wasDenied) {
          widget.onPermissionGranted?.call();
        }
      }
    } catch (_) {}
  }

  Future<void> _handleFix() async {
    if (_isPermanentlyDenied) {
      final Uri settingsUri = Uri.parse('app-settings:');
      if (await canLaunchUrl(settingsUri)) {
        await launchUrl(settingsUri);
      } else {
        await Geolocator.openAppSettings();
      }
      return;
    }

    if (_isServiceDisabled) {
      await Geolocator.openLocationSettings();
      await _checkPermission();
      return;
    }

    final LocationPermission permission =
        await Geolocator.requestPermission();
    if (!mounted) return;

    if (permission == LocationPermission.deniedForever) {
      setState(() {
        _isDenied = true;
        _isPermanentlyDenied = true;
      });
      final Uri settingsUri = Uri.parse('app-settings:');
      if (await canLaunchUrl(settingsUri)) {
        await launchUrl(settingsUri);
      } else {
        await Geolocator.openAppSettings();
      }
    } else if (permission == LocationPermission.denied) {
      setState(() {
        _isDenied = true;
        _isPermanentlyDenied = false;
      });
    } else {
      setState(() {
        _isDenied = false;
        _isPermanentlyDenied = false;
      });
      widget.onPermissionGranted?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isDenied) return const SizedBox.shrink();

    final palette = KinCirclePalette.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _handleFix,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: palette.error.withValues(alpha: 0.16),
            border: Border(
              bottom: BorderSide(
                color: palette.error.withValues(alpha: 0.5),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.location_off_rounded,
                color: palette.error,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Location sharing is off — tap to fix',
                  style: KinCircleTypography.body14(
                    color: palette.error,
                    weight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: palette.error,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
