import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';

import '../design/kincircle_screen_tokens.dart';
import '../models/user_model.dart';
import '../services/location_service.dart';
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
  GoogleMapController? _mapController;

  final Map<String, BitmapDescriptor> _markerCache =
      <String, BitmapDescriptor>{};

  _MapState _state = _MapState.loading;
  String? _error;
  bool _isPermissionPermanentlyDenied = false;
  LatLng _cameraTarget = const LatLng(30.0444, 31.2357);
  Set<Marker> _markers = <Marker>{};
  List<_MemberRowData> _members = <_MemberRowData>[];
  int _currentBatteryLevel = 0;
  double _currentUserSpeedKmh = 0.0;

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
    _refreshCurrentBatteryLevel();
    _initialize();
  }

  @override
  void dispose() {
    _familySub?.cancel();
    _positionSub?.cancel();
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
      if (familyId == null || familyId.isEmpty) {
        if (!mounted) return;
        setState(() {
          _members = <_MemberRowData>[];
          _markers = <Marker>{};
          _state = _MapState.ready;
        });
        return;
      }

      _subscribeToFamilyMembers(familyId);
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
        final List<_MemberRowData> rows = snapshot.docs
          .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
            final AppUser user = AppUser.fromFirestore(doc);
            if (user.lastKnownLocation == null) return null;
            final dynamic rawBattery = doc.data()['batteryLevel'];
            final int? firestoreBattery =
              rawBattery is num ? rawBattery.toInt() : null;
            return _toRowData(user, firestoreBattery: firestoreBattery);
          })
          .whereType<_MemberRowData>()
            .toList();

        final Set<Marker> markers = <Marker>{};
        for (final _MemberRowData row in rows) {
          final BitmapDescriptor icon =
              await _markerForMember(row.user.uid, row.user.displayName);
          final LatLng position = row.user.lastKnownLocation!;
          markers.add(
            Marker(
              markerId: MarkerId(row.user.uid),
              position: position,
              icon: icon,
              infoWindow: InfoWindow(
                title: row.user.displayName,
                snippet: _formatRelative(row.user.lastUpdated),
              ),
            ),
          );
        }

        LatLng nextTarget = _cameraTarget;
        if (rows.isNotEmpty) {
          nextTarget = rows.first.user.lastKnownLocation!;
        }

        if (!mounted) return;
        setState(() {
          _members = rows;
          _markers = markers;
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
    } catch (_) {
      // Keep default battery level on platforms where battery info is unavailable.
    }
  }

  double _speedForUser(DateTime? lastUpdated) {
    // TODO: wire to a real speed field from member location telemetry.
    if (lastUpdated == null) return 0;
    final int minutes = DateTime.now().difference(lastUpdated).inMinutes;
    if (minutes <= 2) return 9;
    if (minutes <= 10) return 3;
    return 0;
  }

  Future<BitmapDescriptor> _markerForMember(String uid, String displayName) async {
    final String key = '$uid-$displayName';
    final BitmapDescriptor? cached = _markerCache[key];
    if (cached != null) {
      return cached;
    }
    final BitmapDescriptor marker = await _buildInitialsMarker(displayName);
    _markerCache[key] = marker;
    return marker;
  }

  Future<BitmapDescriptor> _buildInitialsMarker(String displayName) async {
    const double size = 132;
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    const Offset center = Offset(size / 2, size / 2);
    final Paint ring = Paint()..color = KinCirclePalette.accent;
    final Paint fill = Paint()..color = KinCirclePalette.surfaceAlt;
    canvas.drawCircle(center, size / 2, ring);
    canvas.drawCircle(center, size / 2 - 8, fill);

    final TextPainter painter = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: _initials(displayName),
        style: KinCircleTypography.cardTitle16(
          color: Colors.white,
          weight: FontWeight.w700,
        ),
      ),
    )..layout();
    painter.paint(
      canvas,
      Offset((size - painter.width) / 2, (size - painter.height) / 2),
    );

    final ui.Image image =
        await recorder.endRecording().toImage(size.toInt(), size.toInt());
    final ByteData? data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) return BitmapDescriptor.defaultMarker;
    return BitmapDescriptor.bytes(Uint8List.view(data.buffer));
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
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} h ago';
    return '${diff.inDays} d ago';
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.location_off_rounded,
              color: Color(0xFF00C9A7),
              size: 52,
            ),
            const SizedBox(height: 16),
            Text(
              'Location access required',
              textAlign: TextAlign.center,
              style: KinCircleTypography.body14(
                color: Colors.white,
                weight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'KinCircle needs your location to show family members on the map.',
              textAlign: TextAlign.center,
              style: KinCircleTypography.body14(
                color: KinCirclePalette.textMuted,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isPermissionPermanentlyDenied
                  ? _openSettings
                  : _requestLocationAccess,
              style: KinCircleButtons.primary(),
              child: Text(
                _isPermissionPermanentlyDenied
                    ? 'Open Settings'
                    : 'Grant Location Access',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: KinCirclePalette.error, size: 52),
            const SizedBox(height: 12),
            Text(
              _error ?? 'An error occurred.',
              textAlign: TextAlign.center,
              style: KinCircleTypography.body14(color: KinCirclePalette.textMuted),
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
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.groups_2_outlined,
          color: KinCirclePalette.textMuted,
          size: 36,
        ),
        const SizedBox(height: 12),
        Text(
          'No member locations yet',
          style: KinCircleTypography.body14(color: KinCirclePalette.textMuted),
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
    );
  }

  Widget _buildReady() {
    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(target: _cameraTarget, zoom: 13),
          style: _darkMapStyle,
          onMapCreated: (GoogleMapController controller) {
            _mapController = controller;
          },
          markers: _markers,
          myLocationEnabled: true,
          myLocationButtonEnabled: true,
          zoomControlsEnabled: false,
        ),
        DraggableScrollableSheet(
          minChildSize: 0.15,
          initialChildSize: 0.30,
          maxChildSize: 0.80,
          builder: (BuildContext context, ScrollController controller) {
            return Container(
              decoration: BoxDecoration(
                color: KinCirclePalette.surface,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
                border: Border.all(color: KinCirclePalette.border, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.22),
                    blurRadius: 12,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: KinCirclePalette.textMuted.withValues(alpha: 0.4),
                      borderRadius: KinCircleRadii.pill,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text('Family Members', style: KinCircleTypography.cardTitle16()),
                        ),
                        const Spacer(),
                        Expanded(
                          child: Text('${_members.length}', style: KinCircleTypography.caption12()),
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
                                  color: KinCirclePalette.surfaceAlt,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: KinCirclePalette.border, width: 1),
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 20,
                                      backgroundColor: KinCirclePalette.accent.withValues(alpha: 0.2),
                                      child: Text(
                                        _initials(row.user.displayName),
                                        style: KinCircleTypography.caption12(
                                          color: Colors.white,
                                          weight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            row.user.displayName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: KinCircleTypography.body14(weight: FontWeight.w600),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _formatRelative(row.user.lastUpdated),
                                            style: KinCircleTypography.caption12(),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
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
                                              style: KinCircleTypography.caption12(
                                                color: _batteryColor(battery),
                                                weight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          stationary
                                              ? '0 km/h'
                                              : '${row.speedKmh.toStringAsFixed(0)} km/h',
                                          style: KinCircleTypography.caption12(
                                            color: KinCirclePalette.textMuted,
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
