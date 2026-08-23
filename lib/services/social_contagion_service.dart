import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

/// Social contagion service for sharing positivity across real family circles
class SocialContagionService extends ChangeNotifier {
  static final SocialContagionService _instance = SocialContagionService._internal();
  factory SocialContagionService() => _instance;
  SocialContagionService._internal();

  StreamSubscription<User?>? _authStateSub;
  bool _initialized = false;
  int _communityActiveCount = 0;
  int _todayCheckIns = 0;
  int _circleMemberCount = 0;

  // Getters
  int get communityActiveCount => _communityActiveCount;
  int get todayCheckIns => _todayCheckIns;
  int get circleMemberCount => _circleMemberCount;

  /// Initialize the service
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    try {
      _authStateSub?.cancel();
      _authStateSub = FirebaseAuth.instance.authStateChanges().listen(
        (User? user) async {
          if (user == null) {
            _communityActiveCount = 0;
            _todayCheckIns = 0;
            _circleMemberCount = 0;
            notifyListeners();
            return;
          }
          await _loadCommunityStats();
          await _loadCircleStats();
        },
        onError: (Object error) {
          if (kDebugMode) {
            debugPrint('SocialContagionService auth listener error: $error');
          }
        },
      );

      if (kDebugMode) {
        debugPrint('SocialContagionService initialized');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error initializing SocialContagionService: $e');
      }
    }
  }

  /// Load community statistics from Firestore
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

  /// Load circle statistics for current authenticated user
  Future<void> _loadCircleStats() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final familyId = userDoc.data()?['currentFamilyId'] as String?;
      if (familyId != null && familyId.isNotEmpty) {
        final famDoc = await FirebaseFirestore.instance
            .collection('families')
            .doc(familyId)
            .get();
        final members = famDoc.data()?['members'] as List<dynamic>?;
        _circleMemberCount = members?.length ?? 0;
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error loading circle stats: $e');
      }
    }
  }

  /// Spread positivity after a family event with real circle count
  Future<Map<String, dynamic>> spreadPositivity(String eventType) async {
    await _loadCircleStats();
    await _loadCommunityStats();

    // Record the positive event
    await _recordPositiveEvent(eventType, _circleMemberCount);

    final message = _circleMemberCount > 0
        ? 'Moment shared with your family circle'
        : 'Positive moment shared';

    return {
      'message': message,
      'impactCount': _circleMemberCount,
      'communityCount': _communityActiveCount,
    };
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

  /// Real community milestone message based on Firestore metrics
  String getCommunityMilestone() {
    if (_todayCheckIns > 0) {
      return '$_todayCheckIns moments shared today!';
    }
    return '';
  }

  /// Generate social proof message based on real count
  String generateSocialProof(int count) {
    if (count <= 0) return '';
    if (count == 1) return '1 family member in your circle';
    return '$count family members in your circle';
  }

  /// Get nearby activity summary from real data
  Future<String> getNearbyActivity() async {
    if (_communityActiveCount > 0) {
      return '$_communityActiveCount active today';
    }
    return '';
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
    _authStateSub?.cancel();
    _authStateSub = null;
    _initialized = false;
    super.dispose();
  }
}
