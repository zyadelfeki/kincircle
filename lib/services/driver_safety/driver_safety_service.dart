import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:activity_recognition_flutter/activity_recognition_flutter.dart';
import 'interpreter.dart';

part 'pipeline.dart';
part 'repository.dart';

/// Contract for driver incidents captured on-device.
class DriverIncident {
  DriverIncident(
      {required this.timestamp, required this.type, required this.score});
  final DateTime timestamp;
  final String type; // e.g., harsh_brake, sharp_turn, rapid_accel
  final double score; // 0..1 severity

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'type': type,
        'score': score,
      };

  static DriverIncident fromJson(Map obj) => DriverIncident(
        timestamp: DateTime.parse(obj['timestamp'] as String),
        type: obj['type'] as String,
        score: (obj['score'] as num).toDouble(),
      );
}

/// On-device driver safety service: collects data and stores incidents in Hive.
/// Note: Sensor-based functionality temporarily disabled during activity recognition upgrade.
class DriverSafetyService extends ChangeNotifier {
  DriverSafetyService({
    String modelAsset = 'assets/models/driver_safety.tflite',
    Future<dynamic> Function()? repoFactory,
    Future<DriverInterpreter> Function(String asset)? interpreterFactory,
  })  : _modelAsset = modelAsset,
        _repoFactory = repoFactory ?? _IncidentRepository.create,
        _interpreterFactory = interpreterFactory;

  final _pipeline = DriverSensorPipeline(windowSize: 64, sampleHz: 50);
  final Future<dynamic> Function() _repoFactory;
  final String _modelAsset;

  // Active sensor monitoring
  StreamSubscription<AccelerometerEvent>? _accelSub;
  StreamSubscription<GyroscopeEvent>? _gyroSub;
  StreamSubscription<ActivityEvent>? _activitySub;
  DriverInterpreter? _interpreter;
  final Future<DriverInterpreter> Function(String asset)? _interpreterFactory;
  
  // Activity recognition for context-aware monitoring
  bool _isVehicleContext = false;

  // UI Data Properties
  List<DriverIncident> _recentIncidents = [];
  int _weeklyHarshBrakes = 0;
  int _weeklyRapidAccel = 0;
  int _weeklySharpTurns = 0;
  int _weeklyTotalTrips = 0;
  int _safetyScore = 85; // Default score
  bool _isLoading = false;

  // Getters for UI consumption
  List<DriverIncident> get recentIncidents => _recentIncidents;
  int get weeklyHarshBrakes => _weeklyHarshBrakes;
  int get weeklyRapidAccel => _weeklyRapidAccel;
  int get weeklySharpTurns => _weeklySharpTurns;
  int get weeklyTotalTrips => _weeklyTotalTrips;
  int get safetyScore => _safetyScore;
  bool get isLoading => _isLoading;

  Future<void> start() async {
    // lazy init model and repository
    _interpreter ??= await (_interpreterFactory?.call(_modelAsset) ??
        (throw StateError('No interpreterFactory provided')));
    await _repoFactory(); // ensure repository initialized

    // Start activity recognition for context awareness
    await _startActivityRecognition();
    
    // Start sensor monitoring for driving incident detection
    await _startSensorMonitoring();

    if (kDebugMode) {
      print('DriverSafetyService: Service started with full sensor monitoring');
    }
  }

  Future<void> stop() async {
    await _accelSub?.cancel();
    await _gyroSub?.cancel();
    await _activitySub?.cancel();
    _accelSub = null;
    _gyroSub = null;
    _activitySub = null;
    
    if (kDebugMode) {
      print('DriverSafetyService: Service stopped');
    }
  }

  Future<List<DriverIncident>> getRecent({int limit = 50}) async {
    final repo = await _repoFactory();
    return repo.getRecent(limit: limit);
  }

  /// Fetches and calculates weekly summary data for UI display
  Future<void> fetchWeeklySummary() async {
    _isLoading = true;
    notifyListeners();

    try {
      final repo = await _repoFactory();
      final now = DateTime.now().toUtc();
      final weekStart = now.subtract(const Duration(days: 7));
      
      // Get incidents from the last 7 days
      final incidents = await repo.getSince(weekStart);
      _recentIncidents = incidents.take(10).toList(); // Show last 10 incidents
      
      // Calculate weekly counts
      _weeklyHarshBrakes = incidents.where((i) => i.type == 'harsh_brake').length;
      _weeklyRapidAccel = incidents.where((i) => i.type == 'rapid_accel').length;
      _weeklySharpTurns = incidents.where((i) => i.type == 'sharp_turn').length;
      
      // Calculate estimated trips (rough estimation based on incident patterns)
      // For now, use a simple heuristic: incidents typically happen during trips
      final incidentDays = incidents.map((i) => DateTime(i.timestamp.year, i.timestamp.month, i.timestamp.day)).toSet();
      _weeklyTotalTrips = max(incidentDays.length * 2, 1); // Estimate 2 trips per active day
      
      // Calculate safety score (100 = perfect, decreases with incidents)
      final totalIncidents = _weeklyHarshBrakes + _weeklyRapidAccel + _weeklySharpTurns;
      _safetyScore = max(100 - (totalIncidents * 5), 0); // Decrease by 5 points per incident
      
      if (kDebugMode) {
        print('DriverSafetyService: Weekly summary updated - Score: $_safetyScore, Incidents: $totalIncidents');
      }
    } catch (e) {
      if (kDebugMode) {
        print('DriverSafetyService: Error fetching weekly summary - $e');
      }
      // Set default values on error
      _recentIncidents = [];
      _weeklyHarshBrakes = 0;
      _weeklyRapidAccel = 0;
      _weeklySharpTurns = 0;
      _weeklyTotalTrips = 0;
      _safetyScore = 100;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Reads last 7 days of incidents from local Hive, aggregates counts, and uploads
  /// an anonymized weekly summary to users/{uid}/driver_safety_summaries.
  /// Fields uploaded:
  /// - period_start (string yyyy-mm-dd)
  /// - periodStart (Firestore Timestamp)
  /// - harsh_braking_count (int)
  /// - rapid_accel_count (int)
  Future<void> uploadWeeklySummary() async {
    final repo = await _repoFactory();
    final now = DateTime.now().toUtc();
    final since = now.subtract(const Duration(days: 7));
    final incidents = await repo.getSince(since);

    int harsh = 0;
    int accel = 0;
    for (final i in incidents) {
      if (i.type == 'harsh_brake') harsh++;
      if (i.type == 'rapid_accel') accel++;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return; // not signed in, skip

    // Use the date part of the start as the document ID for idempotency
    final periodStartDate = _fmtDate(since);
    final periodStartTs = Timestamp.fromDate(since);

    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('driver_safety_summaries')
        .doc(periodStartDate);

    await docRef.set({
      'period_start': periodStartDate,
      'periodStart': periodStartTs,
      'harsh_braking_count': harsh,
      'rapid_accel_count': accel,
      'createdAt': FieldValue.serverTimestamp(),
      'source': 'mobile',
    }, SetOptions(merge: true));
  }

  /// Attempts an upload only if 7 days have passed since the last upload marker.
  Future<void> uploadWeeklySummaryIfNeeded(
      {Duration minInterval = const Duration(days: 7)}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastMs = prefs.getInt('driver_last_summary_upload_ms') ?? 0;
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      if (nowMs - lastMs < minInterval.inMilliseconds) return;
      await uploadWeeklySummary();
      await prefs.setInt('driver_last_summary_upload_ms', nowMs);
    } catch (_) {
      // swallow errors; try on next app open
    }
  }

  String _fmtDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  /// Start activity recognition to detect vehicle context
  Future<void> _startActivityRecognition() async {
    try {
      // Start activity recognition stream
      _activitySub = ActivityRecognition().activityStream().listen((activity) {
        _isVehicleContext = activity.type == ActivityType.IN_VEHICLE;
        if (kDebugMode) {
          print('DriverSafetyService: Activity detected - ${activity.type}, confidence: ${activity.confidence}');
        }
      });
    } catch (e) {
      if (kDebugMode) {
        print('DriverSafetyService: Failed to start activity recognition - $e');
      }
    }
  }

  /// Start sensor monitoring for driving incident detection
  Future<void> _startSensorMonitoring() async {
    final repo = await _repoFactory();
    
    // Monitor accelerometer for harsh braking and rapid acceleration
    _accelSub = accelerometerEventStream().listen((event) {
      if (_isVehicleContext) {
        _pipeline.addAccel(event.x, event.y, event.z);
        _maybeInfer(repo);
      }
    });

    // Monitor gyroscope for sharp turns
    _gyroSub = gyroscopeEventStream().listen((event) {
      if (_isVehicleContext) {
        _pipeline.addGyro(event.x, event.y, event.z);
        _maybeInfer(repo);
      }
    });
  }

  // Exposed for testing: run a single feature vector through the model and persist if above threshold
  Future<void> processFeatures(List<double> features,
      {double threshold = 0.7}) async {
    final repo = await _repoFactory();
    // Ensure interpreter is available in non-start() contexts (e.g., tests)
    _interpreter ??= await (_interpreterFactory?.call(_modelAsset) ??
        (throw StateError('No interpreterFactory provided')));
    final result = _infer(features);
    if (result != null && result.score > threshold) {
      await repo.save(result);
    }
  }

  // Run inference when pipeline has sufficient data and we're in vehicle context
  void _maybeInfer(_IncidentRepository repo) {
    if (!_pipeline.ready || !_isVehicleContext) return;
    final input = _pipeline.popWindow();
    final result = _infer(input);
    if (result != null && result.score > 0.7) {
      repo.save(result);
      // Update UI data and notify listeners
      _recentIncidents.insert(0, result);
      if (_recentIncidents.length > 10) {
        _recentIncidents = _recentIncidents.take(10).toList();
      }
      // Update weekly counts
      switch (result.type) {
        case 'harsh_brake':
          _weeklyHarshBrakes++;
          break;
        case 'rapid_accel':
          _weeklyRapidAccel++;
          break;
        case 'sharp_turn':
          _weeklySharpTurns++;
          break;
      }
      // Recalculate safety score
      final totalIncidents = _weeklyHarshBrakes + _weeklyRapidAccel + _weeklySharpTurns;
      _safetyScore = max(100 - (totalIncidents * 5), 0);
      
      notifyListeners(); // Notify UI of changes
      
      if (kDebugMode) {
        print('DriverSafetyService: Incident detected - ${result.type} (score: ${result.score})');
      }
    }
  }

  DriverIncident? _infer(List<double> features) {
    final interpreter = _interpreter;
    if (interpreter == null) return null;
    // Model contract: [1, N] input, [1, 3] output: [brake, turn, accel]
    final scores = interpreter.run(features);
    final classes = ['harsh_brake', 'sharp_turn', 'rapid_accel'];
    final maxIdx = scores.indexed.reduce((a, b) => a.$2 > b.$2 ? a : b).$1;
    final score = scores[maxIdx];
    return DriverIncident(
        timestamp: DateTime.now(), type: classes[maxIdx], score: score);
  }
}
