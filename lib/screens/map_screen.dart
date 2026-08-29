import 'dart:async';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';

import '../design/kincircle_screen_tokens.dart';
import '../models/user_model.dart';
import '../services/circle_status_service.dart';
import '../services/anomaly_alert_service.dart';
import '../services/location_service.dart';
import '../services/geofence_monitor_service.dart';
import '../services/theme_controller.dart';
import '../widgets/nav_shell.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

enum _MapState {
  loading,
  ready,
  permissionDenied,
  error,
}

class _MemberRowData {
  const _MemberRowData({
    required this.user,
    required this.batteryPercent,
    required this.speedKmh,
  });

  final AppUser user;
  final int batteryPercent;
  final double speedKmh;
}

class _MapScreenState extends State<MapScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final LocationService _locationService = LocationService();
  final Battery _battery = Battery();

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _familySub;
  StreamSubscription<Position>? _positionSub;
  StreamSubscription<List<CircleMemberStatusEntry>>? _statusSub;
  StreamSubscription<User?>? _authSub;
  GoogleMapController? _mapController;

  final Map<String, BitmapDescriptor> _markerCache =
      <String, BitmapDescriptor>{};
  final Map<String, List<Map<String, dynamic>>> _memberLocationHistory =
      <String, List<Map<String, dynamic>>>{};

  _MapState _state = _MapState.loading;
  String? _error;
  String? _currentFamilyId;
  bool _isPermissionPermanentlyDenied = false;
  bool _isProUser = false;
  bool _privacyBubbleMode = false;
  LatLng _cameraTarget = const LatLng(30.0444, 31.2357);
  Set<Marker> _markers = <Marker>{};
  Set<Circle> _circles = <Circle>{};
  List<_MemberRowData> _members = <_MemberRowData>[];
  String? _currentCircleId;
  List<CircleMemberStatusEntry> _circleStatuses =
      <CircleMemberStatusEntry>[];
  int _currentBatteryLevel = 0;
  double _currentUserSpeedKmh = 0.0;

  static const String _privacyBubblePrefsKey = 'map.privacyBubble';

  static const String _darkMapStyle = '''
[
  {"elementType":"geometry","stylers":[{"color":"#1d2c4d"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#8ec3b9"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#1a3646"}]},
  {"featureType":"administrative.country","elementType":"geometry.stroke","stylers":[{"color":"#4b6878"}]},
  {"featureType":"landscape.natural","elementType":"geometry","stylers":[{"color":"#023e58"}]},
  {"featureType":"poi","elementType":"geometry","stylers":[{"color":"#283d6a"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#304a7d"}]},
  {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#2c6675"}]},
  {"featureType":"transit.station","elementType":"geometry","stylers":[{"color":"#3a4762"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#0e1626"}]}
]
''';

  @override
  void initState() {
    super.initState();
    _authSub = _auth.authStateChanges().listen((User? user) {
      if (user == null) {
        _familySub?.cancel();
        _familySub = null;
        _positionSub?.cancel();
        _positionSub = null;
        _statusSub?.cancel();
        _statusSub = null;
      }
    });
    _refreshCurrentBatteryLevel();
    _bootstrap();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _isProUser = context.read<ThemeController>().isPro;
  }

  Future<void> _bootstrap() async {
    await _loadPrivacyBubbleMode();
    if (!mounted) return;
    await _initialize();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _familySub?.cancel();
    _positionSub?.cancel();
    _statusSub?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    setState(() {
      _state = _MapState.loading;
      _error = null;
    });

    try {
      final bool permissionGranted = await _ensureLocationPermission();
      if (!permissionGranted) {
        if (!mounted) return;
        setState(() => _state = _MapState.permissionDenied);
        return;
      }

      _positionSub?.cancel();
      _positionSub = _locationService.startLocationUpdates().listen(
        (Position position) {
          double speedMetersPerSecond = position.speed;
          if (speedMetersPerSecond < 1.0) {
            speedMetersPerSecond = 0.0;
          }
          final double speedKmh = speedMetersPerSecond * 3.6;
          if (mounted) {
            setState(() {
              _currentUserSpeedKmh = speedKmh;
            });
          }
          _locationService.updateUserLocation(position);
        },
      );

      final User? user = _auth.currentUser;
      if (user == null) {
        if (!mounted) return;
        setState(() {
          _state = _MapState.error;
          _error = 'Please sign in to view the live map.';
        });
        return;
      }

      final DocumentSnapshot<Map<String, dynamic>> currentUserDoc =
          await _firestore.collection('users').doc(user.uid).get();
      final String? familyId = currentUserDoc.data()?['currentFamilyId'] as String?;
      final String? circleId = currentUserDoc.data()?['circleId'] as String?;
      if (familyId == null || familyId.isEmpty) {
        if (!mounted) return;
        setState(() {
          _currentFamilyId = null;
          _currentCircleId = null;
          _members = <_MemberRowData>[];
          _markers = <Marker>{};
          _circles = <Circle>{};
          _state = _MapState.ready;
        });
        return;
      }

      _currentFamilyId = familyId;
      _currentCircleId = (circleId != null && circleId.isNotEmpty)
          ? circleId
          : familyId;
      _subscribeToFamilyMembers(familyId);
      _subscribeToCircleStatuses(_currentCircleId!);
      GeofenceMonitorService().startMonitoring(familyId: familyId);
      if (!mounted) return;
      setState(() => _state = _MapState.ready);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _state = _MapState.error;
        _error = 'Failed to load map data.';
      });
    }
  }

  Future<void> _loadPrivacyBubbleMode() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final bool enabled = prefs.getBool(_privacyBubblePrefsKey) ?? false;
    if (!mounted) return;
    setState(() {
      _privacyBubbleMode = enabled;
    });
  }

  Future<void> _togglePrivacyBubbleMode() async {
    final bool next = !_privacyBubbleMode;
    if (!mounted) return;
    setState(() {
      _privacyBubbleMode = next;
      if (!next) {
        _circles = <Circle>{};
      }
    });

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_privacyBubblePrefsKey, next);

    final String? familyId = _currentFamilyId;
    if (familyId != null && familyId.isNotEmpty) {
      _subscribeToFamilyMembers(familyId);
    }
  }

  LatLng _markerPositionForMode(String uid, LatLng exactPosition) {
    if (!_privacyBubbleMode || uid.isEmpty) return exactPosition;
    final double jitter = (uid.codeUnits.first % 10) * 0.0001;
    return LatLng(
      exactPosition.latitude + jitter,
      exactPosition.longitude + jitter,
    );
  }

  Future<bool> _ensureLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      _isPermissionPermanentlyDenied = true;
      return false;
    }

    if (permission == LocationPermission.denied) {
      _isPermissionPermanentlyDenied = false;
      return false;
    }

    _isPermissionPermanentlyDenied = false;
    return true;
  }

  Future<void> _requestLocationAccess() async {
    final LocationPermission permission = await Geolocator.requestPermission();
    if (!mounted) return;
    if (permission == LocationPermission.deniedForever) {
      setState(() {
        _isPermissionPermanentlyDenied = true;
        _state = _MapState.permissionDenied;
      });
      return;
    }
    if (permission == LocationPermission.denied) {
      setState(() {
        _isPermissionPermanentlyDenied = false;
        _state = _MapState.permissionDenied;
      });
      return;
    }
    await _initialize();
  }

  void _subscribeToFamilyMembers(String familyId) {
    _familySub?.cancel();
    _familySub = _firestore
        .collection('users')
        .where('currentFamilyId', isEqualTo: familyId)
        .snapshots()
        .listen(
      (QuerySnapshot<Map<String, dynamic>> snapshot) async {
        final bool bubbleMode = _privacyBubbleMode;
        final List<_MemberRowData> rows = snapshot.docs
          .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
            final AppUser user = AppUser.fromFirestore(doc);
            if (user.isInvisible) return null;
            if (user.lastKnownLocation == null) return null;
            final dynamic rawBattery = doc.data()['batteryLevel'];
            final int? firestoreBattery =
              rawBattery is num ? rawBattery.toInt() : null;
            return _toRowData(user, firestoreBattery: firestoreBattery);
          })
          .whereType<_MemberRowData>()
          .toList();

        _recordLocationHistory(rows);
        if (_isProUser && familyId.isNotEmpty) {
          final List<Map<String, dynamic>> history = _memberLocationHistory
              .values
              .expand((List<Map<String, dynamic>> items) => items)
              .toList();
          AnomalyAlertService.checkForAnomalies(familyId, history);
        }

        final Set<Marker> markers = <Marker>{};
        final Set<Circle> circles = <Circle>{};
        for (final _MemberRowData row in rows) {
          final String memberName = _safeDisplayName(row.user.displayName);
          final BitmapDescriptor icon =
              await _markerForMember(row.user.uid, memberName);
          final LatLng exactPosition = row.user.lastKnownLocation!;
          final LatLng position = bubbleMode
              ? _markerPositionForMode(row.user.uid, exactPosition)
              : exactPosition;

          markers.add(
            Marker(
              markerId: MarkerId(row.user.uid),
              position: position,
              icon: icon,
              anchor: const Offset(0.5, 0.68),
              infoWindow: InfoWindow(
                title: memberName,
                snippet: _formatRelative(row.user.lastUpdated),
              ),
            ),
          );

          if (bubbleMode) {
            circles.add(
              Circle(
                circleId: CircleId(row.user.uid),
                center: position,
                radius: 300,
                fillColor: Colors.blue.withValues(alpha: 0.15),
                strokeColor: Colors.blue.withValues(alpha: 0.4),
                strokeWidth: 1,
              ),
            );
          }
        }

        LatLng nextTarget = _cameraTarget;
        if (rows.isNotEmpty) {
          nextTarget = bubbleMode
              ? _markerPositionForMode(
                  rows.first.user.uid,
                  rows.first.user.lastKnownLocation!,
                )
              : rows.first.user.lastKnownLocation!;
        }

        if (!mounted) return;
        setState(() {
          _members = rows;
          _markers = markers;
          _circles = circles;
          _cameraTarget = nextTarget;
        });
      },
      onError: (_) {
        if (!mounted) return;
        setState(() {
          _state = _MapState.error;
          _error = 'Could not stream family members.';
        });
      },
    );
  }

  void _subscribeToCircleStatuses(String circleId) {
    _statusSub?.cancel();
    _statusSub = CircleStatusService.instance
        .watchCircleStatuses(circleId)
        .listen((List<CircleMemberStatusEntry> statuses) {
      if (!mounted) return;
      setState(() {
        _circleStatuses = statuses;
      });
    }, onError: (Object error) {
      debugPrint('MapScreen status stream error: $error');
    });
  }

  Future<void> _broadcastCircleStatus(
    CircleMemberStatus status,
    String confirmation,
  ) async {
    try {
      await CircleStatusService.instance.broadcastStatus(status);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(confirmation)),
      );
    } catch (e) {
      debugPrint('MapScreen status broadcast error: $e');
    }
  }

  void _recordLocationHistory(List<_MemberRowData> rows) {
    final DateTime now = DateTime.now();
    final DateTime cutoff = now.subtract(const Duration(hours: 2));

    for (final _MemberRowData row in rows) {
      final String uid = row.user.uid;
      final LatLng? position = row.user.lastKnownLocation;
      if (uid.isEmpty || position == null) continue;

      final List<Map<String, dynamic>> history =
          _memberLocationHistory.putIfAbsent(uid, () => <Map<String, dynamic>>[]);
      history.add(<String, dynamic>{
        'uid': uid,
        'displayName': _safeDisplayName(row.user.displayName),
        'lat': position.latitude,
        'lng': position.longitude,
        'timestamp': row.user.lastUpdated ?? now,
        'speed': row.speedKmh,
      });

      history.removeWhere(
        (Map<String, dynamic> item) =>
            (item['timestamp'] as DateTime).isBefore(cutoff),
      );

      if (history.length > 50) {
        history.removeRange(0, history.length - 50);
      }
    }
  }

  _MemberRowData _toRowData(AppUser user, {int? firestoreBattery}) {
    final bool isCurrentUser = _auth.currentUser?.uid == user.uid;
    final int battery = _batteryForUser(
      isCurrentUser: isCurrentUser,
      firestoreBattery: firestoreBattery,
    );
    final double speedKmh =
        isCurrentUser ? _currentUserSpeedKmh : _speedForUser(user.lastUpdated);
    return _MemberRowData(
      user: user,
      batteryPercent: battery,
      speedKmh: speedKmh,
    );
  }

  int _batteryForUser({required bool isCurrentUser, int? firestoreBattery}) {
    if (isCurrentUser) {
      return _currentBatteryLevel.clamp(0, 100);
    }
    if (firestoreBattery != null) {
      return firestoreBattery.clamp(0, 100);
    }
    return 0;
  }

  Future<void> _refreshCurrentBatteryLevel() async {
    try {
      final int level = await _battery.batteryLevel;
      if (!mounted) return;
      setState(() {
        _currentBatteryLevel = level;
      });
    } catch (_) {}
  }

  double _speedForUser(DateTime? lastUpdated) {
    if (lastUpdated == null) return 0;
    final int minutes = DateTime.now().difference(lastUpdated).inMinutes;
    if (minutes <= 2) return 9;
    if (minutes <= 10) return 3;
    return 0;
  }

  Future<BitmapDescriptor> _markerForMember(String uid, String displayName) async {
    final String key = '$uid-$displayName';
    final BitmapDescriptor? cached = _markerCache[key];
    if (cached != null) return cached;
    final BitmapDescriptor marker = await _buildInitialsMarker(displayName);
    _markerCache[key] = marker;
    return marker;
  }

  Future<BitmapDescriptor> _buildInitialsMarker(String displayName) async {
    const double width = 128;
    const double height = 158;
    const double avatarSize = 88;
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    const Offset center = Offset(width / 2, avatarSize / 2 + 4);
    final String memberName = _markerLabel(displayName);

    final Paint ring = Paint()..color = KinCirclePalette.accent;
    final Paint fill = Paint()..color = KinCirclePalette.surfaceAlt;
    canvas.drawCircle(center, avatarSize / 2, ring);
    canvas.drawCircle(center, avatarSize / 2 - 7, fill);

    final TextPainter painter = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: _initials(memberName),
        style: KinCircleTypography.cardTitle16(
          color: KinCirclePalette.textPrimary,
          weight: FontWeight.w700,
        ),
      ),
    )..layout();
    painter.paint(
      canvas,
      Offset((width - painter.width) / 2, (avatarSize - painter.height) / 2 + 4),
    );

    const double labelTop = 106;
    const double labelHorizontalPadding = 10;
    const Rect labelRect = Rect.fromLTWH(10, labelTop, width - 20, 32);
    final RRect labelRRect = RRect.fromRectAndRadius(labelRect, const Radius.circular(12));
    canvas.drawRRect(labelRRect, Paint()..color = KinCirclePalette.surface);
    canvas.drawRRect(
      labelRRect,
      Paint()
        ..color = KinCirclePalette.border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    final TextPainter namePainter = TextPainter(
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
      text: TextSpan(
        text: memberName,
        style: KinCircleTypography.caption12(
          color: KinCirclePalette.textPrimary,
          weight: FontWeight.w600,
        ),
      ),
    )..layout(maxWidth: width - (labelHorizontalPadding * 2) - 20);
    namePainter.paint(
      canvas,
      Offset((width - namePainter.width) / 2, labelTop + 9),
    );

    final ui.Image image =
        await recorder.endRecording().toImage(width.toInt(), height.toInt());
    final ByteData? data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) return BitmapDescriptor.defaultMarker;
    return BitmapDescriptor.bytes(Uint8List.view(data.buffer));
  }

  String _safeDisplayName(String displayName) {
    final String trimmed = displayName.trim();
    final String lowered = trimmed.toLowerCase();
    if (trimmed.isEmpty || lowered == 'u' || lowered == 'no name') return 'Unknown';
    return trimmed;
  }

  String _markerLabel(String displayName) {
    final String safe = _safeDisplayName(displayName);
    final String firstToken = safe.split(' ').first.trim();
    if (firstToken.isEmpty) return safe;
    if (firstToken.length <= 12) return firstToken;
    return '${firstToken.substring(0, 12)}…';
  }

  String _initials(String displayName) {
    final List<String> parts = displayName
        .trim()
        .split(' ')
        .where((String part) => part.trim().isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  Future<void> _centerOnMyLocation() async {
    await HapticFeedback.lightImpact();
    Position? pos;
    try {
      pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          timeLimit: Duration(seconds: 5),
        ),
      );
    } catch (_) {
      pos = null;
    }
    pos ??= _locationService.lastWrittenPosition;

    if (pos != null && _mapController != null) {
      await _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(pos.latitude, pos.longitude),
          16,
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Locating… check location permission'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _openSettings() async {
    final Uri settingsUri = Uri.parse('app-settings:');
    if (await canLaunchUrl(settingsUri)) {
      await launchUrl(settingsUri);
      return;
    }
    await Geolocator.openAppSettings();
  }

  String _formatRelative(DateTime? value) {
    if (value == null) return 'Last seen unknown';
    final Duration diff = DateTime.now().difference(value);
    if (diff.inHours >= 3) {
      final int hours = diff.inHours;
      return 'Signal lost · ${hours}h ago';
    }
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    return '${diff.inHours} h ago';
  }

  Color _batteryColor(int value) {
    if (value > 50) return const Color(0xFF22C55E);
    if (value >= 20) return const Color(0xFFF59E0B);
    return KinCirclePalette.error;
  }

  Widget _buildLoading() {
    return Stack(
      children: [
        Container(color: KinCirclePalette.surfaceAlt),
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(16),
            decoration: KinCircleDecorations.card(),
            child: Shimmer.fromColors(
              baseColor: KinCirclePalette.surfaceAlt,
              highlightColor: KinCirclePalette.border,
              child: Column(
                children: List<Widget>.generate(4, (int i) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(height: 12, width: 120, color: Colors.white),
                              const SizedBox(height: 8),
                              Container(height: 10, width: 80, color: Colors.white),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPermissionDenied() {
    final palette = KinCirclePalette.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_off_rounded, color: palette.accent, size: 52),
            const SizedBox(height: 16),
            Text(
              'Location access required',
              textAlign: TextAlign.center,
              style: KinCircleTypography.body14(
                color: palette.textPrimary,
                weight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'KinCircle needs your location to show family members on the map.',
              textAlign: TextAlign.center,
              style: KinCircleTypography.body14(color: palette.textMuted),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isPermissionPermanentlyDenied
                  ? _openSettings
                  : _requestLocationAccess,
              style: KinCircleButtons.primary(),
              child: Text(
                _isPermissionPermanentlyDenied
                    ? 'Open settings'
                    : 'Grant location access',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    final palette = KinCirclePalette.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: palette.error, size: 52),
            const SizedBox(height: 12),
            Text(
              _error ?? 'An error occurred.',
              textAlign: TextAlign.center,
              style: KinCircleTypography.body14(color: palette.textMuted),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _initialize,
              style: KinCircleButtons.primary(),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptySheet() {
    final palette = KinCirclePalette.of(context);
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.groups_2_outlined, color: palette.textMuted, size: 36),
          const SizedBox(height: 12),
          Text(
            'No member locations yet',
            style: KinCircleTypography.body14(color: palette.textMuted),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ElevatedButton(
              style: KinCircleButtons.primary(),
              onPressed: () => Navigator.of(context).pushNamed('/invite'),
              child: const Text('Invite member'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReady() {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      children: [
        _PulseMapCanvas(
          cameraTarget: _cameraTarget,
          isDark: isDark,
          markers: _markers,
          circles: _circles,
          circleStatuses: _circleStatuses,
          onMapCreated: (GoogleMapController controller) {
            _mapController = controller;
          },
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: MediaQuery.of(context).padding.bottom + 112,
          child: SafeArea(
            child: Column(
              children: [
                Row(
                  children: [
                    Flexible(
                      flex: 4,
                      child: ElevatedButton.icon(
                        onPressed: () => _broadcastCircleStatus(
                          CircleMemberStatus.safe,
                          'Status shared with your circle',
                        ),
                        icon: const Icon(Icons.check_circle_outline_rounded),
                        label: const Text('I\'m safe'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: KinCirclePalette.accent,
                          foregroundColor: Colors.black,
                          minimumSize: const Size(0, 48),
                          textStyle: KinCircleTypography.body14(
                            color: Colors.black,
                            weight: FontWeight.w600,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      flex: 6,
                      child: ElevatedButton.icon(
                        onPressed: () => _broadcastCircleStatus(
                          CircleMemberStatus.needsHelp,
                          'Circle members notified',
                        ),
                        icon: const Icon(Icons.sos_rounded),
                        label: const Text('Need help'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: KinCirclePalette.error,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(0, 48),
                          textStyle: KinCircleTypography.body14(
                            color: Colors.white,
                            weight: FontWeight.w600,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 2,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
        Positioned(
          top: 14,
          right: 14,
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Builder(
                  builder: (ctx) {
                    final fabPalette = KinCirclePalette.of(ctx);
                    return Material(
                      color: fabPalette.surface,
                      borderRadius: BorderRadius.circular(14),
                      elevation: 6,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: fabPalette.border),
                        ),
                        child: IconButton(
                          tooltip: _privacyBubbleMode
                              ? 'Disable privacy bubbles'
                              : 'Enable privacy bubbles',
                          onPressed: _togglePrivacyBubbleMode,
                          icon: Icon(
                            _privacyBubbleMode
                                ? Icons.blur_circular
                                : Icons.location_on_rounded,
                            color: fabPalette.accent,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),
                Builder(
                  builder: (ctx) {
                    final fabPalette = KinCirclePalette.of(ctx);
                    return Material(
                      color: fabPalette.surface,
                      borderRadius: BorderRadius.circular(14),
                      elevation: 6,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: fabPalette.border),
                        ),
                        child: IconButton(
                          tooltip: 'My location',
                          onPressed: _centerOnMyLocation,
                          icon: Icon(
                            Icons.my_location_rounded,
                            color: fabPalette.accent,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: MediaQuery.of(context).size.height * 0.8,
          child: DraggableScrollableSheet(
            minChildSize: 0.15,
            initialChildSize: 0.30,
            maxChildSize: 0.80,
            expand: false,
            snap: true,
            snapSizes: const <double>[0.15, 0.30, 0.80],
            builder: (BuildContext context, ScrollController controller) {
              final palette = KinCirclePalette.of(context);
              return Container(
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                  border: Border.all(color: palette.border, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.34),
                      blurRadius: 22,
                      spreadRadius: 1,
                      offset: const Offset(0, -8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    // Drag handle pill only — no label
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: palette.textMuted.withValues(alpha: 0.4),
                          borderRadius: KinCircleRadii.pill,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _members.length <= 1 && _members.isNotEmpty
                          ? Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                _safeDisplayName(_members.first.user.displayName),
                                style: KinCircleTypography.cardTitle16(
                                  color: palette.textPrimary,
                                ),
                              ),
                            )
                          : Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Family members',
                                    style: KinCircleTypography.cardTitle16(
                                      color: palette.textPrimary,
                                    ),
                                  ),
                                ),
                                if (_members.length > 1)
                                  Text(
                                    '${_members.length}',
                                    style: KinCircleTypography.caption12(
                                      color: palette.textSecondary,
                                    ),
                                  ),
                              ],
                            ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: _members.isEmpty
                          ? _buildEmptySheet()
                          : ListView.builder(
                              controller: controller,
                              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                              itemCount: _members.length,
                              itemBuilder: (BuildContext context, int index) {
                                final _MemberRowData row = _members[index];
                                final int battery = row.batteryPercent;
                                final bool stationary = row.speedKmh <= 0;
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: palette.surfaceAlt,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: palette.border,
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 20,
                                        backgroundColor:
                                            palette.accent.withValues(alpha: 0.2),
                                        child: Text(
                                          _initials(_safeDisplayName(
                                              row.user.displayName)),
                                          style: KinCircleTypography.caption12(
                                            color: palette.textPrimary,
                                            weight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _safeDisplayName(
                                                  row.user.displayName),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: KinCircleTypography.body14(
                                                color: palette.textPrimary,
                                                weight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              _formatRelative(
                                                  row.user.lastUpdated),
                                              style:
                                                  KinCircleTypography.caption12(
                                                color: palette.textMuted,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.battery_std_rounded,
                                                size: 15,
                                                color: _batteryColor(battery),
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                '$battery%',
                                                style:
                                                    KinCircleTypography.caption12(
                                                  color: _batteryColor(battery),
                                                  weight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            stationary
                                                ? 'At current location'
                                                : '${row.speedKmh.toStringAsFixed(0)} km/h',
                                            style: KinCircleTypography.caption12(
                                              color: palette.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBody() {
    switch (_state) {
      case _MapState.loading:
        return _buildLoading();
      case _MapState.permissionDenied:
        return _buildPermissionDenied();
      case _MapState.error:
        return _buildError();
      case _MapState.ready:
        return _buildReady();
    }
  }

  @override
  Widget build(BuildContext context) {
    return NavShell(
      currentIndex: 0,
      title: 'Live Map',
      body: _buildBody(),
    );
  }
}

class _PulseMapCanvas extends StatefulWidget {
  const _PulseMapCanvas({
    required this.cameraTarget,
    required this.isDark,
    required this.markers,
    required this.circles,
    required this.circleStatuses,
    required this.onMapCreated,
  });

  final LatLng cameraTarget;
  final bool isDark;
  final Set<Marker> markers;
  final Set<Circle> circles;
  final List<CircleMemberStatusEntry> circleStatuses;
  final void Function(GoogleMapController controller) onMapCreated;

  @override
  State<_PulseMapCanvas> createState() => _PulseMapCanvasState();
}

class _PulseMapCanvasState extends State<_PulseMapCanvas>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _updateAnimation();
  }

  @override
  void didUpdateWidget(covariant _PulseMapCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateAnimation();
  }

  void _updateAnimation() {
    final bool hasHelp = widget.circleStatuses.any(
      (CircleMemberStatusEntry s) =>
          s.status == CircleMemberStatus.needsHelp,
    );
    if (hasHelp) {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
    } else {
      if (_pulseController.isAnimating) {
        _pulseController.stop();
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Set<Circle> _buildNeedsHelpCircles(double pulse) {
    final bool hasHelp = widget.circleStatuses.any(
      (CircleMemberStatusEntry s) =>
          s.status == CircleMemberStatus.needsHelp,
    );
    if (!hasHelp) return const <Circle>{};

    final Map<String, LatLng> markerPositions = <String, LatLng>{
      for (final Marker marker in widget.markers)
        marker.markerId.value: marker.position,
    };

    final double radius = 180 + (110 * pulse);

    return widget.circleStatuses
        .where((CircleMemberStatusEntry status) =>
            status.status == CircleMemberStatus.needsHelp)
        .map((CircleMemberStatusEntry status) {
      final LatLng? position = markerPositions[status.uid];
      if (position == null) return null;
      return Circle(
        circleId: CircleId('needs_help_${status.uid}'),
        center: position,
        radius: radius,
        fillColor: Colors.red.withValues(alpha: 0.16 + (0.12 * pulse)),
        strokeColor: Colors.red.withValues(alpha: 0.45 + (0.35 * pulse)),
        strokeWidth: 2,
      );
    }).whereType<Circle>().toSet();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (BuildContext context, _) {
        final Set<Circle> helpCircles =
            _buildNeedsHelpCircles(_pulseController.value);
        return GoogleMap(
          gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
            Factory<OneSequenceGestureRecognizer>(
              () => EagerGestureRecognizer(),
            ),
          },
          initialCameraPosition:
              CameraPosition(target: widget.cameraTarget, zoom: 13),
          style: widget.isDark ? _MapScreenState._darkMapStyle : null,
          onMapCreated: widget.onMapCreated,
          markers: widget.markers,
          circles: <Circle>{...widget.circles, ...helpCircles},
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          zoomGesturesEnabled: true,
          scrollGesturesEnabled: true,
          rotateGesturesEnabled: true,
          tiltGesturesEnabled: true,
        );
      },
    );
  }
}
