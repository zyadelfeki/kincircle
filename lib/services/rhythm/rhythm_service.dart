import 'dart:async';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    String? Function()? currentDisplayNameProvider,
    DateTime Function()? nowProvider,
    FutureOr<bool> Function()? isProProvider,
    this.onPatternBreak,
  })  : _store = rhythmStore ?? RhythmStore.instance,
        _geofenceMonitor =
            geofenceMonitorService ?? GeofenceMonitorService.instance,
        _transitionStreamOverride = transitionStreamOverride,
        _authInstance = auth,
        _firestoreInstance = firestore,
        _currentUidProvider = currentUidProvider,
        _currentDisplayNameProvider = currentDisplayNameProvider,
        _nowProvider = nowProvider,
        _isProProvider = isProProvider {
    _listenAuthChanges();
  }

  factory RhythmService({
    RhythmStore? rhythmStore,
    GeofenceMonitorService? geofenceMonitorService,
    Stream<GeofenceTransitionEvent>? transitionStreamOverride,
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    String? Function()? currentUidProvider,
    String? Function()? currentDisplayNameProvider,
    DateTime Function()? nowProvider,
    FutureOr<bool> Function()? isProProvider,
    Future<void> Function(GeofenceTarget geofence, RhythmBaseline baseline, DateTime timestamp)? onPatternBreak,
  }) {
    if (rhythmStore != null ||
        geofenceMonitorService != null ||
        transitionStreamOverride != null ||
        auth != null ||
        firestore != null ||
        currentUidProvider != null ||
        currentDisplayNameProvider != null ||
        nowProvider != null ||
        isProProvider != null ||
        onPatternBreak != null) {
      return RhythmService._internal(
        rhythmStore: rhythmStore,
        geofenceMonitorService: geofenceMonitorService,
        transitionStreamOverride: transitionStreamOverride,
        auth: auth,
        firestore: firestore,
        currentUidProvider: currentUidProvider,
        currentDisplayNameProvider: currentDisplayNameProvider,
        nowProvider: nowProvider,
        isProProvider: isProProvider,
        onPatternBreak: onPatternBreak,
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
  final String? Function()? _currentDisplayNameProvider;
  final DateTime Function()? _nowProvider;
  final FutureOr<bool> Function()? _isProProvider;
  Future<void> Function(GeofenceTarget geofence, RhythmBaseline baseline, DateTime timestamp)? onPatternBreak;

  FirebaseAuth? _authInstance;
  FirebaseFirestore? _firestoreInstance;

  FirebaseAuth get _auth => _authInstance ??= FirebaseAuth.instance;
  FirebaseFirestore get firestore =>
      _firestoreInstance ??= FirebaseFirestore.instance;

  StreamSubscription<GeofenceTransitionEvent>? _transitionSub;
  StreamSubscription<User?>? _authSub;
  Timer? _periodicCheckTimer;
  bool _isRunning = false;
  bool _isStarting = false;
  String? _runningUid;

  final Map<String, String> _lastAnomalyFiredDateByGeofenceId = <String, String>{};

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

  /// Start rhythm service (listening to geofence transitions & periodic 15-min check).
  Future<void> start() async {
    final uid = _currentUid();
    if (uid == null || uid.isEmpty) {
      return;
    }

    if (_isRunning && _runningUid == uid && _transitionSub != null) {
      return;
    }

    if (_isStarting) {
      return;
    }
    _isStarting = true;

    try {
      await _store.init();
      _isRunning = true;
      _runningUid = uid;

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

      _periodicCheckTimer?.cancel();
      _periodicCheckTimer = Timer.periodic(
        const Duration(minutes: 15),
        (_) => evaluatePatternBreaks(),
      );

      if (kDebugMode) {
        debugPrint('RhythmService started for user $uid');
      }
    } finally {
      _isStarting = false;
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

    // Check pattern breaks on transitions as well
    await evaluatePatternBreaks(evaluationTime: event.timestamp);
  }

  /// Evaluates whether any monitored safe place has broken its arrival baseline.
  Future<List<RhythmBaseline>> evaluatePatternBreaks({
    DateTime? evaluationTime,
    List<GeofenceTarget>? geofencesOverride,
    bool Function(String geofenceId)? isInsideGeofenceOverride,
  }) async {
    final String? uid = _currentUid();
    if (uid == null || uid.isEmpty) {
      return <RhythmBaseline>[];
    }

    final DateTime currentTime = evaluationTime ?? now;
    final String todayKey =
        '${currentTime.year}-${currentTime.month.toString().padLeft(2, '0')}-${currentTime.day.toString().padLeft(2, '0')}';
    final double currentMins = RhythmStore.minutesSinceMidnight(currentTime);
    final String dayType = RhythmStore.resolveDayType(currentTime);
    final List<GeofenceTarget> targets =
        geofencesOverride ?? _geofenceMonitor.geofences;

    final List<RhythmBaseline> triggered = <RhythmBaseline>[];

    for (final geofence in targets) {
      final RhythmBaseline? baseline = _store.getBaseline(
        userId: uid,
        geofenceId: geofence.id,
        dayType: dayType,
      );

      // Condition 1: Sample count >= 5
      if (baseline == null || baseline.sampleCount < 5) {
        continue;
      }

      // Condition 2: Current time past ewmaArrival + max(2 * stdDev, 30 mins)
      final double stdDev = baseline.standardDeviation;
      final double margin = math.max(2.0 * stdDev, 30.0);
      final double cutoff = baseline.ewmaArrivalMinutes + margin;

      if (currentMins <= cutoff) {
        continue;
      }

      // Condition 3: User is NOT currently inside that geofence
      final bool isInside = isInsideGeofenceOverride != null
          ? isInsideGeofenceOverride(geofence.id)
          : _geofenceMonitor.isInsideGeofence(geofence.id);
      if (isInside) {
        continue;
      }

      // Condition 4: No anomaly was fired for this geofence today
      final String? lastFired = _lastAnomalyFiredDateByGeofenceId[geofence.id];
      if (lastFired == todayKey) {
        continue;
      }

      // Mark fired today before side effects to avoid duplicate triggers
      _lastAnomalyFiredDateByGeofenceId[geofence.id] = todayKey;
      triggered.add(baseline);

      await _handlePatternBreak(
        geofence: geofence,
        baseline: baseline,
        timestamp: currentTime,
      );
    }

    return triggered;
  }

  Future<bool> _checkIsPro() async {
    if (_isProProvider != null) {
      return await _isProProvider!();
    }
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      return prefs.getBool('subscription.isPro') ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _handlePatternBreak({
    required GeofenceTarget geofence,
    required RhythmBaseline baseline,
    required DateTime timestamp,
  }) async {
    if (onPatternBreak != null) {
      await onPatternBreak!(geofence, baseline, timestamp);
    }

    final bool pro = await _checkIsPro();
    if (!pro) {
      if (kDebugMode) {
        debugPrint(
            'RhythmService: Pattern break detected for free user (no alert docs written)');
      }
      return;
    }

    final myUid = _currentUid();
    if (myUid == null || myUid.isEmpty) return;
    final String familyId = geofence.familyId;
    if (familyId.isEmpty) return;

    // Resolve display name
    String myDisplayName = ((_currentDisplayNameProvider != null
                ? _currentDisplayNameProvider!()
                : _auth.currentUser?.displayName) ??
            '')
        .trim();
    if (myDisplayName.isEmpty) {
      try {
        final userDoc = await firestore.collection('users').doc(myUid).get();
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

    final String title =
        '$myDisplayName usually arrives at ${geofence.name} by ~${baseline.formattedArrival} — no arrival yet';
    final String message = title;

    try {
      final familyDoc =
          await firestore.collection('families').doc(familyId).get();
      if (!familyDoc.exists) return;

      final members =
          (familyDoc.data()?['members'] as List<dynamic>? ?? <dynamic>[])
              .cast<String>();

      final otherMembers = members.where((uid) => uid != myUid).toList();
      if (otherMembers.isEmpty) return;

      final batch = firestore.batch();
      for (final otherUid in otherMembers) {
        final docRef = firestore.collection('alerts').doc();
        batch.set(docRef, {
          'userId': otherUid,
          'familyId': familyId,
          'triggeredByUid': myUid,
          'triggeredByName': myDisplayName,
          'title': title,
          'message': message,
          'timestamp': FieldValue.serverTimestamp(),
          'type': 'pattern',
          'seen': false,
        });
      }
      await batch.commit();
      if (kDebugMode) {
        debugPrint(
            'RhythmService: Dispatched pattern alert to ${otherMembers.length} members: $title');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('RhythmService: Failed to write pattern alerts: $e');
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
    _runningUid = null;
    _isStarting = false;
  }

  /// Cancel and clean up all subscriptions (alias for stop).
  void cancel() {
    stop();
  }

  /// Resets anomaly fired cooldown tracker (useful for tests).
  @visibleForTesting
  void resetCooldownsForTesting() {
    _lastAnomalyFiredDateByGeofenceId.clear();
  }

  void dispose() {
    _authSub?.cancel();
    stop();
  }
}
