import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'dart:math';

/// Social contagion service for spreading positivity and creating FOMO
/// Research: Facebook study (689,003 users) showed emotional states spread digitally
/// Positive content exposure increases user positivity by 15%
class SocialContagionService extends ChangeNotifier {
  static final SocialContagionService _instance = SocialContagionService._internal();
  factory SocialContagionService() => _instance;
  SocialContagionService._internal();

  Timer? _fomoTimer;
  int _communityActiveCount = 0;
  int _todayCheckIns = 0;

  // Getters
  int get communityActiveCount => _communityActiveCount;
  int get todayCheckIns => _todayCheckIns;

  /// Initialize the service
  Future<void> initialize() async {
    try {
      await _loadCommunityStats();
      _startFOMOLoop();

      if (kDebugMode) {
        debugPrint('SocialContagionService initialized');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error initializing SocialContagionService: $e');
      }
    }
  }

  /// Load community statistics
  Future<void> _loadCommunityStats() async {
    try {
      final stats = await FirebaseFirestore.instance
          .collection('community')
          .doc('stats')
          .get();

      if (stats.exists) {
        final data = stats.data()!;
        _communityActiveCount = data['activeToday'] ?? 0;
        _todayCheckIns = data['checkInsToday'] ?? 0;
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error loading community stats: $e');
      }
    }
  }

  /// Spread positivity after a family event
  Future<Map<String, dynamic>> spreadPositivity(String eventType) async {
    final message = _generateContagiousMessage(eventType);
    final impactCount = _generateImpactCount();
    
    // Record the positive event
    await _recordPositiveEvent(eventType, impactCount);

    return {
      'message': message,
      'impactCount': impactCount,
      'communityCount': _communityActiveCount,
    };
  }

  /// Generate contagious message
  String _generateContagiousMessage(String eventType) {
    final random = Random();
    final impactCount = _generateImpactCount();

    final templates = [
      'Your $eventType inspired $impactCount nearby families!',
      'Family love is contagious - you started $impactCount connections!',
      'Your check-in created a ripple of $impactCount family moments!',
      '$impactCount families felt your positive energy!',
      'Amazing! Your $eventType spread joy to $impactCount families!',
      'You sparked $impactCount family interactions today!',
      'Your care reached $impactCount families nearby!',
    ];

    return templates[random.nextInt(templates.length)];
  }

  /// Generate realistic impact count (12-89 range)
  int _generateImpactCount() {
    final random = Random();
    return 12 + random.nextInt(78); // 12-89
  }

  /// Record positive event in Firestore
  Future<void> _recordPositiveEvent(String eventType, int impactCount) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('community')
          .doc('positive_events')
          .collection('events')
          .add({
        'userId': user.uid,
        'eventType': eventType,
        'impactCount': impactCount,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Update community stats
      await FirebaseFirestore.instance
          .collection('community')
          .doc('stats')
          .set({
        'checkInsToday': FieldValue.increment(1),
        'lastUpdate': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error recording positive event: $e');
      }
    }
  }

  /// Start FOMO loop with variable reward timing
  void _startFOMOLoop() {
    _scheduleFOMONotification();
  }

  void _scheduleFOMONotification() {
    _fomoTimer?.cancel();

    final interval = _getRandomInterval();
    _fomoTimer = Timer(interval, () {
      _triggerFOMONotification();
      _scheduleFOMONotification(); // Schedule next
    });
  }

  /// Get random interval (1-8 hours)
  Duration _getRandomInterval() {
    final random = Random();
    final hours = 1 + random.nextInt(8); // 1-8 hours
    final minutes = random.nextInt(60);
    return Duration(hours: hours, minutes: minutes);
  }

  /// Trigger FOMO notification
  void _triggerFOMONotification() {
    // This would integrate with notification system
    final messages = [
      'Sarah just shared a family moment',
      '23 families are celebrating together!',
      'Your family circle is active right now',
      '15 families checked in nearby',
      'The Johnson family hit their milestone!',
    ];

    final message = messages[Random().nextInt(messages.length)];
    
    if (kDebugMode) {
      debugPrint('🔔 FOMO Notification: $message');
    }

    // TODO: Integrate with actual notification service
  }

  /// Generate community milestone message
  String getCommunityMilestone() {
    final milestones = [
      '10,000 families connected today!',
      '50,000 check-ins this week!',
      '1 million moments shared!',
      '100,000 families stronger together!',
      'Community growing by 1,000 families daily!',
    ];

    return milestones[Random().nextInt(milestones.length)];
  }

  /// Generate social proof message
  String generateSocialProof(int count) {
    if (count < 10) {
      return 'families like yours';
    } else if (count < 50) {
      return 'families in your area';
    } else if (count < 100) {
      return 'families celebrating nearby';
    } else {
      return 'families across the community';
    }
  }

  /// Get nearby activity summary
  Future<String> getNearbyActivity() async {
    final count = 5 + Random().nextInt(20); // 5-24
    return '$count families checked in nearby';
  }

  /// Record user influenced by social contagion
  Future<void> recordContagionInfluence(String sourceEventId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('community')
          .doc('contagion_tracking')
          .collection('influences')
          .add({
        'userId': user.uid,
        'sourceEventId': sourceEventId,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error recording contagion influence: $e');
      }
    }
  }

  @override
  void dispose() {
    _fomoTimer?.cancel();
    super.dispose();
  }
}

/// FOMO Engine for creating variable reward loops
class FOMOEngine {
  static Timer? _timer;

  /// Create FOMO loop with unpredictable timing
  static void createFOMOLoop(Function(String, String) onNotification) {
    _timer?.cancel();
    _scheduleNext(onNotification);
  }

  static void _scheduleNext(Function(String, String) onNotification) {
    final interval = _getRandomInterval();
    
    _timer = Timer(interval, () {
      final notification = _generateFOMONotification();
      onNotification(notification['title']!, notification['body']!);
      _scheduleNext(onNotification); // Reschedule
    });
  }

  static Duration _getRandomInterval() {
    final random = Random();
    final hours = 1 + random.nextInt(8); // 1-8 hours
    final minutes = random.nextInt(60);
    return Duration(hours: hours, minutes: minutes);
  }

  static Map<String, String> _generateFOMONotification() {
    final random = Random();
    final count = 5 + random.nextInt(20);

    final notifications = [
      {
        'title': 'Family Activity Alert',
        'body': '$count families are celebrating together!'
      },
      {
        'title': 'Your Circle is Active',
        'body': 'Sarah just shared a special moment'
      },
      {
        'title': 'Community Milestone',
        'body': '1,000 families reached today\'s goal!'
      },
      {
        'title': 'Nearby Families',
        'body': '$count families checked in nearby'
      },
      {
        'title': 'Family Streak Alert',
        'body': 'The Martinez family hit 30 days!'
      },
    ];

    return notifications[random.nextInt(notifications.length)];
  }

  static void stop() {
    _timer?.cancel();
  }
}
