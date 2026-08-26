import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import 'location_service.dart';

class GeofenceTarget {
  final String id;
  final String name;
  final String familyId;
  final double latitude;
  final double longitude;
  final double radius;

  const GeofenceTarget({
    required this.id,
    required this.name,
    required this.familyId,
    required this.latitude,
    required this.longitude,
    required this.radius,
  });

  factory GeofenceTarget.fromFirestore(String id, Map<String, dynamic> data) {
    double lat = 0.0;
    double lng = 0.0;
    if (data['lat'] is num) {
      lat = (data['lat'] as num).toDouble();
    } else if (data['latitude'] is num) {
      lat = (data['latitude'] as num).toDouble();
    } else if (data['center'] is GeoPoint) {
      lat = (data['center'] as GeoPoint).latitude;
    }

    if (data['lng'] is num) {
      lng = (data['lng'] as num).toDouble();
    } else if (data['longitude'] is num) {
      lng = (data['longitude'] as num).toDouble();
    } else if (data['center'] is GeoPoint) {
      lng = (data['center'] as GeoPoint).longitude;
    }

    double rad = 200.0;
    if (data['radius'] is num) {
      rad = (data['radius'] as num).toDouble();
    } else if (data['radiusMeters'] is num) {
      rad = (data['radiusMeters'] as num).toDouble();
    }

    final name = (data['name'] as String?)?.trim();

    return GeofenceTarget(
      id: id,
      name: (name != null && name.isNotEmpty) ? name : 'Safe Place',
      familyId: (data['familyId'] as String?) ?? '',
      latitude: lat,
      longitude: lng,
      radius: rad,
    );
  }
}

class _GeofenceTrackState {
  bool? confirmedInside;
  bool? candidateInside;
  int consecutiveCandidateCount = 0;
  DateTime? lastAlertTime;
}

/// Client-side service that tracks family geofences and creates alerts for transitions.
class GeofenceMonitorService {
  GeofenceMonitorService._internal({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    LocationService? locationService,
    Stream<Position>? positionStream,
    String? Function()? currentUidProvider,
    String? Function()? currentDisplayNameProvider,
  })  : _firestoreInstance = firestore,
        _authInstance = auth,
        _locationServiceInstance = locationService,
        _positionStreamOverride = positionStream,
        _currentUidProvider = currentUidProvider,
        _currentDisplayNameProvider = currentDisplayNameProvider;

  factory GeofenceMonitorService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    LocationService? locationService,
    Stream<Position>? positionStream,
    String? Function()? currentUidProvider,
    String? Function()? currentDisplayNameProvider,
  }) {
    if (firestore != null ||
        auth != null ||
        locationService != null ||
        positionStream != null ||
        currentUidProvider != null ||
        currentDisplayNameProvider != null) {
      return GeofenceMonitorService._internal(
        firestore: firestore,
        auth: auth,
        locationService: locationService,
        positionStream: positionStream,
        currentUidProvider: currentUidProvider,
        currentDisplayNameProvider: currentDisplayNameProvider,
      );
    }
    return _instance;
  }

  static final GeofenceMonitorService _instance =
      GeofenceMonitorService._internal();

  FirebaseFirestore? _firestoreInstance;
  FirebaseAuth? _authInstance;
  LocationService? _locationServiceInstance;
  final Stream<Position>? _positionStreamOverride;
  final String? Function()? _currentUidProvider;
  final String? Function()? _currentDisplayNameProvider;

  FirebaseFirestore get _firestore =>
      _firestoreInstance ??= FirebaseFirestore.instance;
  FirebaseAuth get _auth => _authInstance ??= FirebaseAuth.instance;
  LocationService get _locationService =>
      _locationServiceInstance ??= LocationService();

  StreamSubscription<Position>? _positionSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _geofencesSub;

  final Map<String, _GeofenceTrackState> _stateByGeofenceId =
      <String, _GeofenceTrackState>{};
  List<GeofenceTarget> _geofences = <GeofenceTarget>[];
  String? _currentFamilyId;
  bool _isMonitoring = false;

  bool get isMonitoring => _isMonitoring;
  List<GeofenceTarget> get geofences => List.unmodifiable(_geofences);

  String? _currentUid() {
    if (_currentUidProvider != null) {
      return _currentUidProvider!();
    }
    return _auth.currentUser?.uid;
  }

  String? _currentDisplayName() {
    if (_currentDisplayNameProvider != null) {
      return _currentDisplayNameProvider!();
    }
    return _auth.currentUser?.displayName;
  }

  @visibleForTesting
  void setGeofencesForTesting(List<GeofenceTarget> list) {
    _geofences = List.from(list);
  }

  /// Start monitoring geofences for the current authenticated user and family.
  Future<void> startMonitoring({String? familyId}) async {
    final uid = _currentUid();
    if (uid == null) {
      return;
    }

    String? targetFamilyId = familyId ?? _currentFamilyId;
    if (targetFamilyId == null || targetFamilyId.isEmpty) {
      try {
        final userDoc =
            await _firestore.collection('users').doc(uid).get();
        targetFamilyId = userDoc.data()?['currentFamilyId'] as String?;
      } catch (e) {
        debugPrint('GeofenceMonitorService: failed to get currentFamilyId: $e');
      }
    }

    if (targetFamilyId == null || targetFamilyId.isEmpty) {
      return;
    }

    if (_isMonitoring &&
        _currentFamilyId == targetFamilyId &&
        _positionSub != null) {
      return;
    }

    _currentFamilyId = targetFamilyId;
    _isMonitoring = true;

    // Listen to geofences collection for this family
    _geofencesSub?.cancel();
    _geofencesSub = _firestore
        .collection('geofences')
        .where('familyId', isEqualTo: targetFamilyId)
        .snapshots()
        .listen((QuerySnapshot<Map<String, dynamic>> snapshot) {
      _geofences = snapshot.docs
          .map((doc) => GeofenceTarget.fromFirestore(doc.id, doc.data()))
          .toList();
    }, onError: (e) {
      debugPrint('GeofenceMonitorService: geofences snapshot error: $e');
    });

    // Subscribe to position stream
    _positionSub?.cancel();
    final stream = _positionStreamOverride ?? _locationService.positionStream;
    _positionSub = stream.listen(
      (Position position) => processPosition(position),
      onError: (e) {
        debugPrint('GeofenceMonitorService: position stream error: $e');
      },
    );
  }

  /// Stop monitoring and clear subscriptions/state.
  void stopMonitoring() {
    cancel();
  }

  /// Cancel monitoring on sign-out.
  void cancel() {
    _positionSub?.cancel();
    _positionSub = null;
    _geofencesSub?.cancel();
    _geofencesSub = null;
    _stateByGeofenceId.clear();
    _geofences.clear();
    _currentFamilyId = null;
    _isMonitoring = false;
  }

  /// Process a position update and check for geofence transitions.
  Future<void> processPosition(Position position, {DateTime? now}) async {
    if (_geofences.isEmpty) return;

    for (final geofence in _geofences) {
      final double distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        geofence.latitude,
        geofence.longitude,
      );
      final bool isInside = distance <= geofence.radius;
      final state = _stateByGeofenceId.putIfAbsent(
        geofence.id,
        () => _GeofenceTrackState(),
      );

      // Baseline reading on initial startup
      if (state.confirmedInside == null) {
        state.confirmedInside = isInside;
        state.candidateInside = isInside;
        state.consecutiveCandidateCount = 1;
        continue;
      }

      if (state.candidateInside == isInside) {
        state.consecutiveCandidateCount += 1;
      } else {
        state.candidateInside = isInside;
        state.consecutiveCandidateCount = 1;
      }

      // Anti-jitter: Require 2 consecutive readings on new side before transition
      if (state.candidateInside != state.confirmedInside &&
          state.consecutiveCandidateCount >= 2) {
        final currentTime = now ?? DateTime.now();
        final lastAlert = state.lastAlertTime;

        // Minimum 60 seconds between alerts for the same geofence
        if (lastAlert == null ||
            currentTime.difference(lastAlert).inSeconds >= 60) {
          final bool isArrival = state.candidateInside == true;
          state.confirmedInside = state.candidateInside;
          state.lastAlertTime = currentTime;

          await _sendGeofenceAlert(
            geofence: geofence,
            isArrival: isArrival,
          );
        } else {
          // Within 60s cooldown, update confirmed state without duplicate alert
          state.confirmedInside = state.candidateInside;
        }
      }
    }
  }

  Future<void> _sendGeofenceAlert({
    required GeofenceTarget geofence,
    required bool isArrival,
  }) async {
    final myUid = _currentUid();
    if (myUid == null || myUid.isEmpty) return;
    final String familyId = geofence.familyId;
    if (familyId.isEmpty) return;

    // Resolve display name
    String myDisplayName = (_currentDisplayName() ?? '').trim();
    if (myDisplayName.isEmpty) {
      try {
        final userDoc =
            await _firestore.collection('users').doc(myUid).get();
        myDisplayName =
            (userDoc.data()?['displayName'] as String? ?? '').trim();
      } catch (_) {}
    }
    if (myDisplayName.isEmpty) {
      final email = (_auth.currentUser?.email ?? '').trim();
      if (email.contains('@')) {
        myDisplayName = email.split('@').first.trim();
      } else {
        myDisplayName = 'Family member';
      }
    }

    final String action = isArrival ? 'arrived at' : 'left';
    final String title = '$myDisplayName $action ${geofence.name}';
    final String message = title;

    try {
      final familyDoc =
          await _firestore.collection('families').doc(familyId).get();
      if (!familyDoc.exists) return;

      final members =
          (familyDoc.data()?['members'] as List<dynamic>? ?? <dynamic>[])
              .cast<String>();

      final otherMembers = members.where((uid) => uid != myUid).toList();
      if (otherMembers.isEmpty) return;

      final batch = _firestore.batch();
      for (final otherUid in otherMembers) {
        final docRef = _firestore.collection('alerts').doc();
        batch.set(docRef, {
          'userId': otherUid,
          'familyId': familyId,
          'triggeredByUid': myUid,
          'triggeredByName': myDisplayName,
          'title': title,
          'message': message,
          'timestamp': FieldValue.serverTimestamp(),
          'type': 'geofence',
          'seen': false,
        });
      }
      await batch.commit();
    } catch (e) {
      debugPrint('GeofenceMonitorService: failed to write alerts: $e');
    }
  }
}
