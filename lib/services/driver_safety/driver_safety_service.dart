import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'interpreter.dart';

part 'pipeline.dart';
part 'repository.dart';

/// Contract for driver incidents captured on-device.
class DriverIncident {
  final DateTime timestamp;
  final String type; // e.g., harsh_brake, sharp_turn, rapid_accel
  final double score; // 0..1 severity

  DriverIncident({required this.timestamp, required this.type, required this.score});

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

/// On-device driver safety service: collects sensors, infers with TFLite locally, and stores incidents in Hive.
class DriverSafetyService {
  final _pipeline = DriverSensorPipeline(windowSize: 64, sampleHz: 50);
  final Future<dynamic> Function() _repoFactory;
  final String _modelAsset;

  StreamSubscription<AccelerometerEvent>? _accelSub;
  StreamSubscription<GyroscopeEvent>? _gyroSub;
  DriverInterpreter? _interpreter;
  final Future<DriverInterpreter> Function(String asset)? _interpreterFactory;

  DriverSafetyService({
    String modelAsset = 'assets/models/driver_safety.tflite',
    Future<dynamic> Function()? repoFactory,
    Future<DriverInterpreter> Function(String asset)? interpreterFactory,
  })
      : _modelAsset = modelAsset,
        _repoFactory = repoFactory ?? _IncidentRepository.create,
        _interpreterFactory = interpreterFactory;

  Future<void> start() async {
  // lazy init model and repository
  _interpreter ??= await (_interpreterFactory?.call(_modelAsset) ?? (throw StateError('No interpreterFactory provided')));
  final repo = await _repoFactory();

    _accelSub = accelerometerEventStream().listen((e) {
      _pipeline.addAccel(e.x, e.y, e.z);
      _maybeInfer(repo);
    });
    _gyroSub = gyroscopeEventStream().listen((e) {
      _pipeline.addGyro(e.x, e.y, e.z);
      _maybeInfer(repo);
    });
  }

  Future<void> stop() async {
    await _accelSub?.cancel();
    await _gyroSub?.cancel();
    _accelSub = null;
    _gyroSub = null;
  }

  Future<List<DriverIncident>> getRecent({int limit = 50}) async {
    final repo = await _repoFactory();
    return repo.getRecent(limit: limit);
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
  Future<void> uploadWeeklySummaryIfNeeded({Duration minInterval = const Duration(days: 7)}) async {
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

  // Exposed for testing: run a single feature vector through the model and persist if above threshold
  Future<void> processFeatures(List<double> features, {double threshold = 0.7}) async {
  final repo = await _repoFactory();
  // Ensure interpreter is available in non-start() contexts (e.g., tests)
  _interpreter ??= await (_interpreterFactory?.call(_modelAsset) ?? (throw StateError('No interpreterFactory provided')));
    final result = _infer(features);
    if (result != null && result.score > threshold) {
      await repo.save(result);
    }
  }

  void _maybeInfer(_IncidentRepository repo) {
    if (!_pipeline.ready) return;
    final input = _pipeline.popWindow();
    final result = _infer(input);
    if (result != null && result.score > 0.7) {
      repo.save(result);
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
    return DriverIncident(timestamp: DateTime.now(), type: classes[maxIdx], score: score);
  }
}
