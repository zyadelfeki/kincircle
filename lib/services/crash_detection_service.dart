import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'crash_prefs.dart';
import 'emergency_response_service.dart';

class _GSample {
  const _GSample(this.gForce, this.timestamp);

  final double gForce;
  final DateTime timestamp;
}

class _CrashCandidate {
  const _CrashCandidate({
    required this.peakG,
    required this.peakTime,
  });

  final double peakG;
  final DateTime peakTime;
}

class CrashDetectionService {
  CrashDetectionService._();

  static final CrashDetectionService instance = CrashDetectionService._();

  static const int _rollingWindowSize = 50;
  static const Duration _windowDuration = Duration(milliseconds: 300);
  static const Duration _confirmationWindow = Duration(seconds: 2);
  static const Duration _cooldown = Duration(seconds: 10);

  static const double _meanCrashThresholdG = 3.5;
  static const double _peakCrashThresholdG = 5.0;
  static const double _stillnessThresholdG = 1.5;

  final List<_GSample> _samples = <_GSample>[];
  final CrashPrefs _crashPrefs = CrashPrefs();
  final EmergencyResponseService _emergencyResponseService =
      EmergencyResponseService();

  StreamSubscription<AccelerometerEvent>? _accelSub;
  _CrashCandidate? _candidate;
  DateTime? _lastConfirmed;

  bool get isRunning => _accelSub != null;

  Future<void> start() async {
    if (isRunning) return;
    try {
      _accelSub = accelerometerEventStream().listen(
        (AccelerometerEvent event) {
          _onAccelerometer(event);
        },
        onError: (Object error, StackTrace stackTrace) {
          debugPrint('CrashDetectionService stream error: $error');
        },
      );
      debugPrint('CrashDetectionService started');
    } catch (e) {
      debugPrint('CrashDetectionService start error: $e');
    }
  }

  Future<void> stop() async {
    try {
      await _accelSub?.cancel();
      _accelSub = null;
      _samples.clear();
      _candidate = null;
      debugPrint('CrashDetectionService stopped');
    } catch (e) {
      debugPrint('CrashDetectionService stop error: $e');
    }
  }

  void _onAccelerometer(AccelerometerEvent event) {
    try {
      final DateTime now = DateTime.now();
      final double g = sqrt(
            event.x * event.x + event.y * event.y + event.z * event.z,
          ) /
          9.81;

      _samples.add(_GSample(g, now));
      if (_samples.length > _rollingWindowSize) {
        _samples.removeAt(0);
      }

      _checkCandidateTimeout(now);
      _confirmCandidateIfStill(now, g);

      if (_candidate != null) {
        return;
      }

      if (_inCooldown(now)) {
        return;
      }

      final _CrashCandidate? candidate = _findCrashCandidate();
      if (candidate != null) {
        _candidate = candidate;
      }
    } catch (e) {
      debugPrint('CrashDetectionService sample processing error: $e');
    }
  }

  bool _inCooldown(DateTime now) {
    final DateTime? last = _lastConfirmed;
    if (last == null) return false;
    return now.difference(last) < _cooldown;
  }

  void _checkCandidateTimeout(DateTime now) {
    final _CrashCandidate? candidate = _candidate;
    if (candidate == null) return;
    if (now.difference(candidate.peakTime) > _confirmationWindow) {
      _candidate = null;
    }
  }

  void _confirmCandidateIfStill(DateTime now, double g) {
    final _CrashCandidate? candidate = _candidate;
    if (candidate == null) return;
    if (now.difference(candidate.peakTime) > _confirmationWindow) return;

    if (g < _stillnessThresholdG) {
      _candidate = null;
      _lastConfirmed = now;
      _handleConfirmedCrash(candidate.peakG);
    }
  }

  _CrashCandidate? _findCrashCandidate() {
    if (_samples.isEmpty) return null;

    for (int start = 0; start < _samples.length; start++) {
      final DateTime startTs = _samples[start].timestamp;
      final DateTime cutoff = startTs.add(_windowDuration);

      double sum = 0;
      int count = 0;
      double peak = 0;
      DateTime peakTime = startTs;

      for (int i = start; i < _samples.length; i++) {
        final _GSample sample = _samples[i];
        if (sample.timestamp.isAfter(cutoff)) break;

        count++;
        sum += sample.gForce;

        if (sample.gForce > peak) {
          peak = sample.gForce;
          peakTime = sample.timestamp;
        }
      }

      if (count == 0) continue;

      final double mean = sum / count;
      if (mean > _meanCrashThresholdG && peak > _peakCrashThresholdG) {
        return _CrashCandidate(
          peakG: peak,
          peakTime: peakTime,
        );
      }
    }

    return null;
  }

  Future<void> _handleConfirmedCrash(double peakG) async {
    try {
      await _crashPrefs.setLastCrash(
        message: 'Crash candidate confirmed at ${DateTime.now().toIso8601String()} (peak ${peakG.toStringAsFixed(2)}g)',
      );

      final bool delegated = await _triggerEmergencyServiceIfAvailable(peakG);
      if (!delegated) {
        await _writeCrashDocument(peakG);
      }
    } catch (e) {
      debugPrint('CrashDetectionService confirmed crash error: $e');
    }
  }

  Future<bool> _triggerEmergencyServiceIfAvailable(double peakG) async {
    try {
      await _emergencyResponseService.triggerCrashAlert(peakG: peakG);
      return true;
    } on UnimplementedError {
      return false;
    } catch (e) {
      debugPrint('CrashDetectionService triggerCrashAlert unavailable: $e');
      return false;
    }
  }

  Future<void> _writeCrashDocument(double peakG) async {
    try {
      final String? uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null || uid.isEmpty) {
        debugPrint('CrashDetectionService crash write skipped: no uid');
        return;
      }

      await FirebaseFirestore.instance.collection('crashes').doc(uid).set(
        <String, dynamic>{
          'timestamp': FieldValue.serverTimestamp(),
          'peakG': peakG,
          'confirmed': true,
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('CrashDetectionService crash write error: $e');
    }
  }
}
