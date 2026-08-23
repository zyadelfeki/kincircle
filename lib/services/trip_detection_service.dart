import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:activity_recognition_flutter/activity_recognition_flutter.dart' as ar;
import 'package:geolocator/geolocator.dart';

import 'crash_detection_service.dart';
import 'location_service.dart';

class TripDetectionService {
  TripDetectionService._internal();
  factory TripDetectionService() => _instance;
  static final TripDetectionService _instance = TripDetectionService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isInTrip = false;
  DateTime? _tripStartTime;
  String? _currentFamilyId;
  StreamSubscription<ar.ActivityEvent>? _activitySub;
  StreamSubscription<Position>? _locationSub;
  final List<Position> _tripLocations = [];
  Timer? _stillTimer;

  static const Duration _stillDuration = Duration(minutes: 3);

  bool get isRecording => _isInTrip;

  Future<void> initialize() async {
    await _getCurrentFamilyId();
    await _ensurePermissions();
    _activitySub?.cancel();
  final activityRecognition = ar.ActivityRecognition();
  _activitySub = activityRecognition.activityStream().listen(_onActivity);
  }

  Future<void> _ensurePermissions() async {
    // Location permission
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      perm = await Geolocator.requestPermission();
    }
  }

  void _onActivity(ar.ActivityEvent event) {
    if (event.type == ar.ActivityType.inVehicle) {
      if (!_isInTrip) {
        _startTrip();
      }
      _stillTimer?.cancel();
      _stillTimer = null;
    } else {
      if (_isInTrip) {
        _stillTimer?.cancel();
        _stillTimer = Timer(_stillDuration, _stopTrip);
      }
    }
  }

  void _startTrip() {
    _isInTrip = true;
    _tripStartTime = DateTime.now();
    _tripLocations.clear();
    unawaited(CrashDetectionService.instance.start());
    _locationSub?.cancel();
    _locationSub = LocationService()
        .positionStream
        .listen((pos) => _tripLocations.add(pos));
    if (kDebugMode) print('Trip started');
  }

  void _stopTrip() async {
    _isInTrip = false;
    _stillTimer?.cancel();
    _stillTimer = null;
    _locationSub?.cancel();
    await CrashDetectionService.instance.stop();
    if (_tripLocations.length < 2) return;
    final user = _auth.currentUser;
    if (user == null) {
      if (kDebugMode) print('Trip ended but no authenticated user; skipping save');
      return;
    }
    final trip = {
      'userId': user.uid,
      'familyId': _currentFamilyId,
      'startTime': _tripStartTime?.toIso8601String(),
      'endTime': DateTime.now().toIso8601String(),
      'locations': _tripLocations
          .map((p) => {
                'lat': p.latitude,
                'lng': p.longitude,
                'ts': p.timestamp.toIso8601String(),
              })
          .toList(),
    };
    await _firestore.collection('trips').add(trip);
    if (kDebugMode) print('Trip ended and saved');
  }

  Future<void> _getCurrentFamilyId() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final userDoc = await _firestore.collection('users').doc(uid).get();
    _currentFamilyId = userDoc.data()?['familyId'] as String?;
  }

  Future<void> stop() async {
    _activitySub?.cancel();
    _locationSub?.cancel();
    _stillTimer?.cancel();
    _isInTrip = false;
    _tripStartTime = null;
    await CrashDetectionService.instance.stop();
  }

  void dispose() {
    _activitySub?.cancel();
    _locationSub?.cancel();
    _stillTimer?.cancel();
  }
}
