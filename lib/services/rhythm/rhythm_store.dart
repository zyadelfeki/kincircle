import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

/// Represents a baseline arrival rhythm for a specific user, geofence, and day type.
class RhythmBaseline {
  final String userId;
  final String geofenceId;
  final String dayType; // 'weekday' or 'weekend'
  final double ewmaArrivalMinutes; // minutes since midnight (0..1440)
  final double ewmaVariance;
  final int sampleCount;
  final DateTime lastUpdated;

  const RhythmBaseline({
    required this.userId,
    required this.geofenceId,
    required this.dayType,
    required this.ewmaArrivalMinutes,
    required this.ewmaVariance,
    required this.sampleCount,
    required this.lastUpdated,
  });

  double get standardDeviation => math.sqrt(math.max(0.0, ewmaVariance));

  /// Formats the EWMA arrival time as ~HH:MM (24-hour format).
  String get formattedArrival {
    final int totalMins = ewmaArrivalMinutes.round() % 1440;
    final int hours = totalMins ~/ 60;
    final int minutes = totalMins % 60;
    final String hStr = hours.toString().padLeft(2, '0');
    final String mStr = minutes.toString().padLeft(2, '0');
    return '$hStr:$mStr';
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'userId': userId,
        'geofenceId': geofenceId,
        'dayType': dayType,
        'ewmaArrivalMinutes': ewmaArrivalMinutes,
        'ewmaVariance': ewmaVariance,
        'sampleCount': sampleCount,
        'lastUpdated': lastUpdated.toIso8601String(),
      };

  factory RhythmBaseline.fromMap(Map<dynamic, dynamic> map) {
    return RhythmBaseline(
      userId: (map['userId'] as String?) ?? '',
      geofenceId: (map['geofenceId'] as String?) ?? '',
      dayType: (map['dayType'] as String?) ?? 'weekday',
      ewmaArrivalMinutes:
          ((map['ewmaArrivalMinutes'] as num?) ?? 0.0).toDouble(),
      ewmaVariance: ((map['ewmaVariance'] as num?) ?? 0.0).toDouble(),
      sampleCount: (map['sampleCount'] as int?) ?? 0,
      lastUpdated: map['lastUpdated'] != null
          ? DateTime.tryParse(map['lastUpdated'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  RhythmBaseline copyWith({
    String? userId,
    String? geofenceId,
    String? dayType,
    double? ewmaArrivalMinutes,
    double? ewmaVariance,
    int? sampleCount,
    DateTime? lastUpdated,
  }) {
    return RhythmBaseline(
      userId: userId ?? this.userId,
      geofenceId: geofenceId ?? this.geofenceId,
      dayType: dayType ?? this.dayType,
      ewmaArrivalMinutes: ewmaArrivalMinutes ?? this.ewmaArrivalMinutes,
      ewmaVariance: ewmaVariance ?? this.ewmaVariance,
      sampleCount: sampleCount ?? this.sampleCount,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}

/// Hive-backed on-device baseline storage with EWMA learning rate alpha = 0.3.
class RhythmStore {
  RhythmStore({Box<dynamic>? box}) : _box = box;

  static const String boxName = 'rhythm_baselines';
  static const double alpha = 0.3; // Learning rate alpha = 0.3

  Box<dynamic>? _box;
  final Map<String, RhythmBaseline> _inMemoryFallback = <String, RhythmBaseline>{};

  static final RhythmStore instance = RhythmStore();

  static String resolveDayType(DateTime dateTime) {
    // DateTime.weekday: 1 (Mon) .. 7 (Sun)
    return (dateTime.weekday >= 6) ? 'weekend' : 'weekday';
  }

  static double minutesSinceMidnight(DateTime dateTime) {
    return dateTime.hour * 60.0 + dateTime.minute + (dateTime.second / 60.0);
  }

  static String storageKey(String userId, String geofenceId, String dayType) {
    return '${userId}_${geofenceId}_$dayType';
  }

  Future<void> init({Box<dynamic>? box}) async {
    if (box != null) {
      _box = box;
      return;
    }
    if (_box != null && _box!.isOpen) {
      return;
    }
    try {
      if (Hive.isBoxOpen(boxName)) {
        _box = Hive.box<dynamic>(boxName);
      } else {
        _box = await Hive.openBox<dynamic>(boxName);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('RhythmStore: Hive box open fallback to memory: $e');
      }
    }
  }

  RhythmBaseline? getBaseline({
    required String userId,
    required String geofenceId,
    required String dayType,
  }) {
    final String key = storageKey(userId, geofenceId, dayType);
    if (_box != null && _box!.isOpen) {
      final dynamic raw = _box!.get(key);
      if (raw is Map) {
        return RhythmBaseline.fromMap(raw);
      }
    }
    return _inMemoryFallback[key];
  }

  List<RhythmBaseline> getAllBaselines({required String userId}) {
    final List<RhythmBaseline> baselines = <RhythmBaseline>[];
    if (_box != null && _box!.isOpen) {
      for (final dynamic val in _box!.values) {
        if (val is Map) {
          final baseline = RhythmBaseline.fromMap(val);
          if (baseline.userId == userId) {
            baselines.add(baseline);
          }
        }
      }
    } else {
      for (final baseline in _inMemoryFallback.values) {
        if (baseline.userId == userId) {
          baselines.add(baseline);
        }
      }
    }
    return baselines;
  }

  /// Records an arrival and updates the EWMA baseline.
  Future<RhythmBaseline> recordArrival({
    required String userId,
    required String geofenceId,
    required DateTime arrivalTime,
    String? dayType,
  }) async {
    final String resolvedDayType = dayType ?? resolveDayType(arrivalTime);
    final double arrivalMinutes = minutesSinceMidnight(arrivalTime);
    final String key = storageKey(userId, geofenceId, resolvedDayType);

    final RhythmBaseline? existing = getBaseline(
      userId: userId,
      geofenceId: geofenceId,
      dayType: resolvedDayType,
    );

    RhythmBaseline updated;
    if (existing == null || existing.sampleCount == 0) {
      // First sample initialization
      updated = RhythmBaseline(
        userId: userId,
        geofenceId: geofenceId,
        dayType: resolvedDayType,
        ewmaArrivalMinutes: arrivalMinutes,
        ewmaVariance: 0.0,
        sampleCount: 1,
        lastUpdated: arrivalTime,
      );
    } else {
      // EWMA update with alpha = 0.3
      final double delta = arrivalMinutes - existing.ewmaArrivalMinutes;
      final double newMean = existing.ewmaArrivalMinutes + (alpha * delta);
      final double newVariance =
          (1.0 - alpha) * (existing.ewmaVariance + (alpha * delta * delta));

      updated = RhythmBaseline(
        userId: userId,
        geofenceId: geofenceId,
        dayType: resolvedDayType,
        ewmaArrivalMinutes: newMean,
        ewmaVariance: newVariance,
        sampleCount: existing.sampleCount + 1,
        lastUpdated: arrivalTime,
      );
    }

    if (_box != null && _box!.isOpen) {
      await _box!.put(key, updated.toMap());
    } else {
      _inMemoryFallback[key] = updated;
    }

    return updated;
  }

  /// Clears stored baselines (useful for testing).
  Future<void> clear() async {
    _inMemoryFallback.clear();
    if (_box != null && _box!.isOpen) {
      await _box!.clear();
    }
  }

  /// Closes the underlying Hive box.
  Future<void> close() async {
    if (_box != null && _box!.isOpen) {
      await _box!.close();
      _box = null;
    }
  }
}
