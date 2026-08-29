import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../geofence_monitor_service.dart';
import 'rhythm_store.dart';

/// On-device AI service for learning family arrival patterns and detecting pattern breaks.
class RhythmService {
  RhythmService._internal({
    RhythmStore? rhythmStore,
    GeofenceMonitorService? geofenceMonitorService,
    Stream<GeofenceTransitionEvent>? transitionStreamOverride,
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    String? Function()? currentUidProvider,
    DateTime Function()? nowProvider,
  })  : _store = rhythmStore ?? RhythmStore.instance,
        _geofenceMonitor =
            geofenceMonitorService ?? GeofenceMonitorService.instance,
        _transitionStreamOverride = transitionStreamOverride,
        _authInstance = auth,
        _firestoreInstance = firestore,
        _currentUidProvider = currentUidProvider,
        _nowProvider = nowProvider {
    _listenAuthChanges();
  }

  factory RhythmService({
    RhythmStore? rhythmStore,
    GeofenceMonitorService? geofenceMonitorService,
    Stream<GeofenceTransitionEvent>? transitionStreamOverride,
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    String? Function()? currentUidProvider,
    DateTime Function()? nowProvider,
  }) {
    if (rhythmStore != null ||
        geofenceMonitorService != null ||
        transitionStreamOverride != null ||
        auth != null ||
        firestore != null ||
        currentUidProvider != null ||
        nowProvider != null) {
      return RhythmService._internal(
        rhythmStore: rhythmStore,
        geofenceMonitorService: geofenceMonitorService,
        transitionStreamOverride: transitionStreamOverride,
        auth: auth,
        firestore: firestore,
        currentUidProvider: currentUidProvider,
        nowProvider: nowProvider,
      );
    }
    return _instance;
  }

  static final RhythmService _instance = RhythmService._internal();
  static RhythmService get instance => _instance;

  final RhythmStore _store;
  final GeofenceMonitorService _geofenceMonitor;
  final Stream<GeofenceTransitionEvent>? _transitionStreamOverride;
  final String? Function()? _currentUidProvider;
  final DateTime Function()? _nowProvider;

  FirebaseAuth? _authInstance;
  FirebaseFirestore? _firestoreInstance;

  FirebaseAuth get _auth => _authInstance ??= FirebaseAuth.instance;
  FirebaseFirestore get firestore =>
      _firestoreInstance ??= FirebaseFirestore.instance;

  StreamSubscription<GeofenceTransitionEvent>? _transitionSub;
  StreamSubscription<User?>? _authSub;
  Timer? _periodicCheckTimer;
  bool _isRunning = false;

  bool get isRunning => _isRunning;
  RhythmStore get store => _store;

  DateTime get now => _nowProvider != null ? _nowProvider!() : DateTime.now();

  String? _currentUid() {
    if (_currentUidProvider != null) {
      return _currentUidProvider!();
    }
    try {
      return _auth.currentUser?.uid;
    } catch (_) {
      return null;
    }
  }

  void _listenAuthChanges() {
    try {
      _authSub?.cancel();
      _authSub = _auth.authStateChanges().listen((User? user) {
        if (user == null) {
          stop();
        } else {
          start();
        }
      });
    } catch (_) {
      // Firebase not initialized in unit tests
    }
  }

  /// Start rhythm service (listening to geofence transitions).
  Future<void> start() async {
    final uid = _currentUid();
    if (uid == null || uid.isEmpty) {
      return;
    }

    if (_isRunning && _transitionSub != null) {
      return;
    }

    await _store.init();
    _isRunning = true;

    _transitionSub?.cancel();
    final stream =
        _transitionStreamOverride ?? _geofenceMonitor.transitions;
    _transitionSub = stream.listen(
      _onTransitionEvent,
      onError: (e) {
        if (kDebugMode) {
          debugPrint('RhythmService transition error: $e');
        }
      },
    );

    if (kDebugMode) {
      debugPrint('RhythmService started for user $uid');
    }
  }

  /// Handles incoming geofence transition event.
  Future<void> _onTransitionEvent(GeofenceTransitionEvent event) async {
    final uid = _currentUid();
    if (uid == null || uid.isEmpty) return;

    if (event.isArrival) {
      try {
        await _store.recordArrival(
          userId: uid,
          geofenceId: event.geofenceId,
          arrivalTime: event.timestamp,
        );
        if (kDebugMode) {
          debugPrint(
              'RhythmService: Learned arrival at ${event.geofenceName} (${event.geofenceId}) for $uid');
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('RhythmService: recordArrival error: $e');
        }
      }
    }
  }

  /// Stop rhythm service and clear active subscriptions/timers.
  void stop() {
    _transitionSub?.cancel();
    _transitionSub = null;
    _periodicCheckTimer?.cancel();
    _periodicCheckTimer = null;
    _isRunning = false;
  }

  /// Cancel and clean up all subscriptions (alias for stop).
  void cancel() {
    stop();
  }

  void dispose() {
    _authSub?.cancel();
    stop();
  }
}
