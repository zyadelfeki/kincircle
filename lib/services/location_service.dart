import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';

class LocationService with WidgetsBindingObserver {
  LocationService._internal();
  factory LocationService() => _instance;
  static final LocationService _instance = LocationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool? _canShareLocationCache;
  DateTime? _canShareLocationCacheAt;
  static const Duration _locationShareCacheTtl = Duration(seconds: 20);

  static const double movementThresholdMeters = 50.0;
  static const Duration stationaryTimeout = Duration(minutes: 5);

  final StreamController<Position> _positionStreamController = StreamController<Position>.broadcast();
  StreamSubscription<Position>? _geolocatorSub;
  Timer? _stationaryCheckTimer;

  bool _isBackgrounded = false;
  LocationAccuracy _currentAccuracy = LocationAccuracy.high;
  int _currentDistanceFilter = 10;
  DateTime? _lastMovedTime;
  Position? _lastObservedPosition;

  bool get isBackgrounded => _isBackgrounded;
  LocationAccuracy get currentAccuracy => _currentAccuracy;
  int get currentDistanceFilter => _currentDistanceFilter;

  Stream<Position> get positionStream {
    _ensureStreamRunning();
    return _positionStreamController.stream;
  }

  Future<bool> requestPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  Stream<Position> startLocationUpdates() {
    _ensureStreamRunning();
    return _positionStreamController.stream;
  }

  void setAppBackgrounded(bool isBackgrounded) {
    if (_isBackgrounded == isBackgrounded) return;
    _isBackgrounded = isBackgrounded;
    _evaluateAdaptiveAccuracy();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      setAppBackgrounded(true);
    } else if (state == AppLifecycleState.resumed) {
      setAppBackgrounded(false);
    }
  }

  void _onPositionReceived(Position position) {
    final now = DateTime.now();
    if (_lastObservedPosition == null) {
      _lastObservedPosition = position;
      _lastMovedTime = now;
    } else {
      final double distance = Geolocator.distanceBetween(
        _lastObservedPosition!.latitude,
        _lastObservedPosition!.longitude,
        position.latitude,
        position.longitude,
      );

      if (distance >= movementThresholdMeters) {
        _lastObservedPosition = position;
        _lastMovedTime = now;
        if (!_isBackgrounded &&
            (_currentAccuracy != LocationAccuracy.high || _currentDistanceFilter != 10)) {
          _switchStreamAccuracy(LocationAccuracy.high, 10);
        }
      }
    }

    if (_lastMovedTime != null && now.difference(_lastMovedTime!) >= stationaryTimeout) {
      if (_currentAccuracy != LocationAccuracy.medium || _currentDistanceFilter != 50) {
        _switchStreamAccuracy(LocationAccuracy.medium, 50);
      }
    }

    _positionStreamController.add(position);
  }

  void _evaluateAdaptiveAccuracy() {
    final now = DateTime.now();
    if (_isBackgrounded) {
      _switchStreamAccuracy(LocationAccuracy.medium, 50);
    } else if (_lastMovedTime != null && now.difference(_lastMovedTime!) >= stationaryTimeout) {
      _switchStreamAccuracy(LocationAccuracy.medium, 50);
    } else {
      _switchStreamAccuracy(LocationAccuracy.high, 10);
    }
  }

  void _switchStreamAccuracy(LocationAccuracy accuracy, int distanceFilter) {
    if (_currentAccuracy == accuracy &&
        _currentDistanceFilter == distanceFilter &&
        _geolocatorSub != null) {
      return;
    }

    _currentAccuracy = accuracy;
    _currentDistanceFilter = distanceFilter;
    _geolocatorSub?.cancel();
    _geolocatorSub = Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
      ),
    ).listen(_onPositionReceived, onError: (Object error) {
      debugPrint('Location stream error: $error');
    });
  }

  void _ensureStreamRunning() {
    if (_geolocatorSub != null) return;
    try {
      WidgetsBinding.instance.addObserver(this);
    } catch (_) {
      // In non-UI unit tests WidgetsBinding might not be initialized
    }
    _stationaryCheckTimer ??= Timer.periodic(
      const Duration(minutes: 1),
      (_) => _evaluateAdaptiveAccuracy(),
    );
    _switchStreamAccuracy(
      _isBackgrounded ? LocationAccuracy.medium : LocationAccuracy.high,
      _isBackgrounded ? 50 : 10,
    );
  }

  static const Duration minWriteInterval = Duration(seconds: 30);
  static const double minDistanceMeters = 100.0;
  static const Duration heartbeatInterval = Duration(minutes: 5);
  static const double significantDistanceMeters = 500.0;

  DateTime? _lastWriteTime;
  Position? _lastWrittenPosition;

  DateTime? get lastWriteTime => _lastWriteTime;
  Position? get lastWrittenPosition => _lastWrittenPosition;

  bool shouldWriteLocation(Position position, {DateTime? now}) {
    if (_lastWriteTime == null || _lastWrittenPosition == null) {
      return true;
    }
    final currentTime = now ?? DateTime.now();
    final elapsed = currentTime.difference(_lastWriteTime!);
    final distance = Geolocator.distanceBetween(
      _lastWrittenPosition!.latitude,
      _lastWrittenPosition!.longitude,
      position.latitude,
      position.longitude,
    );

    // Always write if 5+ minutes (heartbeat) OR moved 500+ meters
    if (elapsed >= heartbeatInterval || distance >= significantDistanceMeters) {
      return true;
    }

    // Skip if less than 30 seconds since last write AND moved less than 100 meters
    if (elapsed < minWriteInterval && distance < minDistanceMeters) {
      return false;
    }

    // Write if moved >= 100 meters (after minWriteInterval has elapsed)
    if (distance >= minDistanceMeters) {
      return true;
    }

    return false;
  }

  Future<void> updateUserLocation(Position position) async {
    final user = _auth.currentUser;
    if (user == null) return;

    if (!shouldWriteLocation(position)) {
      return;
    }

    try {
      final bool canShare = await _canShareLocation(user.uid);
      if (!canShare) return;

      await _firestore.collection('users').doc(user.uid).update({
        'lastKnownLocation': GeoPoint(position.latitude, position.longitude),
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      _lastWriteTime = DateTime.now();
      _lastWrittenPosition = position;
    } on FirebaseException catch (e) {
      // Log Firebase-specific errors with context
      debugPrint('Firebase error updating location: ${e.code} - ${e.message}');
      // Retry logic for transient failures
      if (e.code == 'unavailable' || e.code == 'deadline-exceeded') {
        await Future.delayed(const Duration(seconds: 2));
        try {
          await _firestore.collection('users').doc(user.uid).update({
            'lastKnownLocation': GeoPoint(position.latitude, position.longitude),
            'lastUpdated': FieldValue.serverTimestamp(),
          });
          _lastWriteTime = DateTime.now();
          _lastWrittenPosition = position;
        } catch (_) {
          // Silent fail on retry - location will update on next position change
        }
      }
    } catch (e) {
      debugPrint('Error updating location: $e');
    }
  }

  Future<bool> _canShareLocation(String uid) async {
    final DateTime now = DateTime.now();
    final DateTime? cachedAt = _canShareLocationCacheAt;
    if (_canShareLocationCache != null &&
        cachedAt != null &&
        now.difference(cachedAt) < _locationShareCacheTtl) {
      return _canShareLocationCache!;
    }

    final DocumentSnapshot<Map<String, dynamic>> userDoc =
        await _firestore.collection('users').doc(uid).get();
    final bool invisibleMode = userDoc.data()?['invisibleMode'] as bool? ?? false;
    final bool canShare = !invisibleMode;
    _canShareLocationCache = canShare;
    _canShareLocationCacheAt = now;
    return canShare;
  }

  Future<Position?> getCurrentLocation() async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
    } catch (e) {
      debugPrint('Error getting location: $e');
      return null;
    }
  }
}
