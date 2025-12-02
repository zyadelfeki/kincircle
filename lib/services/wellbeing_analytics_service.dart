import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math' as math;

/// Comprehensive wellbeing analytics service
/// Infers stress from behavioral patterns and tracks family health
class WellbeingAnalyticsService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  WellbeingMetrics? _currentMetrics;
  List<WellbeingMetrics> _history = [];

  WellbeingMetrics? get currentMetrics => _currentMetrics;
  List<WellbeingMetrics> get history => _history;

  /// Initialize service
  Future<void> initialize() async {
    if (kDebugMode) {
      debugPrint('WellbeingAnalyticsService: Initializing...');
    }
    await refreshMetrics();
  }

  /// Refresh current metrics
  Future<void> refreshMetrics() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      _currentMetrics = await calculateMetrics(user.uid);
      await saveMetrics(user.uid, _currentMetrics!);
      _history = await getHistory(user.uid, days: 7);
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('WellbeingAnalyticsService: Error refreshing metrics: $e');
      }
    }
  }

  /// Stress inference from behavioral patterns (research-backed)
  static Future<StressLevel> inferStress(String userId) async {
    double stressScore = 0.0;

    try {
      // 1. Movement patterns (from location history)
      final locationHistory = await _getLocationHistory(userId, days: 3);
      if (locationHistory.isNotEmpty) {
        final avgSpeed = _calculateAverageSpeed(locationHistory);

        if (avgSpeed < 1.0) {
          stressScore += 15; // Low movement = depression indicator
        }
        if (avgSpeed > 5.0) {
          stressScore += 10; // Erratic movement = anxiety indicator
        }

        // 2. Location revisits (home-bound behavior)
        final homeTime = _calculateHomeTime(locationHistory);
        if (homeTime > 0.8) {
          stressScore += 20; // 80%+ at home indicates isolation
        }

        // 3. Late-night activity (insomnia/stress indicator)
        final lateNightActivity = _calculateLateNightActivity(locationHistory);
        if (lateNightActivity > 0.3) {
          stressScore += 20; // 30%+ activity 11pm-3am
        }
      }

      // 4. App usage patterns
      final usageData = await _getUsagePatterns(userId, days: 3);
      if (usageData['sessionCount'] < 2) {
        stressScore += 15; // Social withdrawal
      }
      if (usageData['avgSessionDuration'] > 30) {
        stressScore += 10; // Escapism behavior (30+ min sessions)
      }

      // 5. Family interaction frequency
      final checkIns = await _getCheckInFrequency(userId, days: 3);
      if (checkIns < 2) {
        stressScore += 15; // Low family connection
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('WellbeingAnalyticsService: Error inferring stress: $e');
      }
    }

    // Classify stress level
    if (stressScore >= 60) return StressLevel.critical;
    if (stressScore >= 40) return StressLevel.high;
    if (stressScore >= 20) return StressLevel.moderate;
    return StressLevel.low;
  }

  /// Calculate comprehensive wellbeing metrics
  Future<WellbeingMetrics> calculateMetrics(String userId) async {
    final stressLevel = await inferStress(userId);
    final socialEngagement = await _calculateSocialEngagement(userId);
    final activityLevel = await _calculateActivityLevel(userId);
    final sleepQuality = await _estimateSleepQuality(userId);
    final familyConnection = await _calculateFamilyConnection(userId);

    final overallScore = _calculateOverallScore(
      stressLevel,
      socialEngagement,
      activityLevel,
      sleepQuality,
      familyConnection,
    );

    return WellbeingMetrics(
      stressLevel: stressLevel,
      stressScore: _getStressScore(stressLevel),
      socialEngagement: socialEngagement,
      activityLevel: activityLevel,
      sleepQuality: sleepQuality,
      familyConnection: familyConnection,
      overallScore: overallScore,
      timestamp: DateTime.now(),
    );
  }

  /// Store metrics in Firestore
  Future<void> saveMetrics(String userId, WellbeingMetrics metrics) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('wellbeing_analytics')
          .add(metrics.toMap());
    } catch (e) {
      if (kDebugMode) {
        debugPrint('WellbeingAnalyticsService: Error saving metrics: $e');
      }
    }
  }

  /// Get wellbeing history
  Future<List<WellbeingMetrics>> getHistory(String userId,
      {int days = 7}) async {
    try {
      final cutoff = DateTime.now().subtract(Duration(days: days));

      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('wellbeing_analytics')
          .where('timestamp', isGreaterThan: Timestamp.fromDate(cutoff))
          .orderBy('timestamp', descending: false)
          .limit(days * 2) // Max 2 entries per day
          .get();

      return snapshot.docs
          .map((doc) => WellbeingMetrics.fromMap(doc.data()))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('WellbeingAnalyticsService: Error getting history: $e');
      }
      return [];
    }
  }

  // PRIVATE HELPER METHODS

  static Future<List<Map<String, dynamic>>> _getLocationHistory(String userId,
      {required int days}) async {
    try {
      final cutoff = DateTime.now().subtract(Duration(days: days));

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('location_history')
          .where('timestamp', isGreaterThan: Timestamp.fromDate(cutoff))
          .orderBy('timestamp', descending: false)
          .limit(500)
          .get();

      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      return [];
    }
  }

  static double _calculateAverageSpeed(List<Map<String, dynamic>> locations) {
    if (locations.length < 2) return 0.0;

    double totalSpeed = 0.0;
    int validSpeeds = 0;

    for (int i = 1; i < locations.length; i++) {
      final prev = locations[i - 1];

      if (prev['speed'] != null) {
        totalSpeed += (prev['speed'] as num).toDouble();
        validSpeeds++;
      }
    }

    return validSpeeds > 0 ? totalSpeed / validSpeeds : 0.0;
  }

  static double _calculateHomeTime(List<Map<String, dynamic>> locations) {
    if (locations.isEmpty) return 0.0;

    // Simplified: assume first location is "home"
    if (locations.isEmpty) return 0.0;

    int atHomeCount = 0;
    final firstLat = locations.first['latitude'] as double?;
    final firstLng = locations.first['longitude'] as double?;

    if (firstLat == null || firstLng == null) return 0.0;

    for (final loc in locations) {
      final lat = loc['latitude'] as double?;
      final lng = loc['longitude'] as double?;

      if (lat == null || lng == null) continue;

      // Check if within ~100m of "home"
      final distance = _calculateDistance(firstLat, firstLng, lat, lng);
      if (distance < 0.1) {
        // 100m
        atHomeCount++;
      }
    }

    return atHomeCount / locations.length;
  }

  static double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // km

    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) *
            math.cos(_degreesToRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  static double _degreesToRadians(double degrees) {
    return degrees * math.pi / 180;
  }

  static double _calculateLateNightActivity(
      List<Map<String, dynamic>> locations) {
    if (locations.isEmpty) return 0.0;

    int lateNightCount = 0;

    for (final loc in locations) {
      final timestamp = (loc['timestamp'] as Timestamp?)?.toDate();
      if (timestamp == null) continue;

      final hour = timestamp.hour;
      if (hour >= 23 || hour <= 3) {
        lateNightCount++;
      }
    }

    return lateNightCount / locations.length;
  }

  static Future<Map<String, dynamic>> _getUsagePatterns(String userId,
      {required int days}) async {
    try {
      final cutoff = DateTime.now().subtract(Duration(days: days));

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('app_usage')
          .where('timestamp', isGreaterThan: Timestamp.fromDate(cutoff))
          .get();

      int sessionCount = snapshot.docs.length;
      double totalDuration = 0.0;

      for (final doc in snapshot.docs) {
        final duration = doc.data()['duration'] as int? ?? 0;
        totalDuration += duration / 60.0; // Convert to minutes
      }

      return {
        'sessionCount': sessionCount,
        'avgSessionDuration': sessionCount > 0 ? totalDuration / sessionCount : 0.0,
      };
    } catch (e) {
      return {'sessionCount': 0, 'avgSessionDuration': 0.0};
    }
  }

  static Future<int> _getCheckInFrequency(String userId,
      {required int days}) async {
    try {
      final cutoff = DateTime.now().subtract(Duration(days: days));

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('check_ins')
          .where('timestamp', isGreaterThan: Timestamp.fromDate(cutoff))
          .get();

      return snapshot.docs.length;
    } catch (e) {
      return 0;
    }
  }

  static Future<double> _calculateSocialEngagement(String userId) async {
    try {
      // Check-ins in last 7 days
      final checkIns = await _getCheckInFrequency(userId, days: 7);

      // Messages sent
      final messages = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('messages')
          .where('timestamp',
              isGreaterThan:
                  Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 7))))
          .get();

      final score = ((checkIns * 10) + (messages.docs.length * 5)).toDouble();
      return math.min(100.0, score);
    } catch (e) {
      return 50.0; // Default moderate
    }
  }

  static Future<double> _calculateActivityLevel(String userId) async {
    try {
      final locations = await _getLocationHistory(userId, days: 7);
      if (locations.isEmpty) return 30.0; // Default low-moderate

      final avgSpeed = _calculateAverageSpeed(locations);
      final homeTime = _calculateHomeTime(locations);

      // More movement = higher activity
      double score = (avgSpeed * 20) + ((1 - homeTime) * 50);
      return math.min(100.0, math.max(0.0, score));
    } catch (e) {
      return 30.0;
    }
  }

  static Future<double> _estimateSleepQuality(String userId) async {
    try {
      final locations = await _getLocationHistory(userId, days: 7);
      if (locations.isEmpty) return 60.0; // Default moderate

      final lateNightActivity = _calculateLateNightActivity(locations);

      // Less late-night activity = better sleep
      double score = (1 - lateNightActivity) * 100;
      return math.min(100.0, math.max(0.0, score));
    } catch (e) {
      return 60.0;
    }
  }

  static Future<double> _calculateFamilyConnection(String userId) async {
    try {
      final checkIns = await _getCheckInFrequency(userId, days: 7);

      // More check-ins = better connection
      double score = checkIns * 15.0;
      return math.min(100.0, score);
    } catch (e) {
      return 40.0; // Default moderate
    }
  }

  static double _calculateOverallScore(
    StressLevel stressLevel,
    double socialEngagement,
    double activityLevel,
    double sleepQuality,
    double familyConnection,
  ) {
    // Convert stress to positive score (inverse)
    final stressScore = _getStressScore(stressLevel);
    final stressPositive = 100.0 - stressScore;

    // Weighted average
    final score = (stressPositive * 0.3) +
        (socialEngagement * 0.2) +
        (activityLevel * 0.15) +
        (sleepQuality * 0.2) +
        (familyConnection * 0.15);

    return math.min(100.0, math.max(0.0, score));
  }

  static double _getStressScore(StressLevel level) {
    switch (level) {
      case StressLevel.low:
        return 10.0;
      case StressLevel.moderate:
        return 30.0;
      case StressLevel.high:
        return 50.0;
      case StressLevel.critical:
        return 80.0;
    }
  }
}

/// Stress level classification
enum StressLevel {
  low, // 0-19 points - Healthy
  moderate, // 20-39 points - Monitor
  high, // 40-59 points - Action needed
  critical, // 60+ points - Urgent intervention
}

/// Comprehensive wellbeing metrics
class WellbeingMetrics {
  final StressLevel stressLevel;
  final double stressScore;
  final double socialEngagement; // 0-100
  final double activityLevel; // 0-100
  final double sleepQuality; // 0-100
  final double familyConnection; // 0-100
  final double overallScore; // 0-100
  final DateTime timestamp;

  const WellbeingMetrics({
    required this.stressLevel,
    required this.stressScore,
    required this.socialEngagement,
    required this.activityLevel,
    required this.sleepQuality,
    required this.familyConnection,
    required this.overallScore,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'stressLevel': stressLevel.index,
      'stressScore': stressScore,
      'socialEngagement': socialEngagement,
      'activityLevel': activityLevel,
      'sleepQuality': sleepQuality,
      'familyConnection': familyConnection,
      'overallScore': overallScore,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  factory WellbeingMetrics.fromMap(Map<String, dynamic> map) {
    return WellbeingMetrics(
      stressLevel: StressLevel.values[map['stressLevel'] as int? ?? 0],
      stressScore: (map['stressScore'] as num?)?.toDouble() ?? 0.0,
      socialEngagement: (map['socialEngagement'] as num?)?.toDouble() ?? 0.0,
      activityLevel: (map['activityLevel'] as num?)?.toDouble() ?? 0.0,
      sleepQuality: (map['sleepQuality'] as num?)?.toDouble() ?? 0.0,
      familyConnection: (map['familyConnection'] as num?)?.toDouble() ?? 0.0,
      overallScore: (map['overallScore'] as num?)?.toDouble() ?? 0.0,
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
