import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

/// Feature IDs for progressive unlock system
enum FeatureId {
  dashboard,
  family,
  safety,
  settings,
  help,
  places,
  circles,
  behavioralInsights,
  advancedEmergency,
  themeCustomization,
}

/// Unlock condition types
enum UnlockCondition {
  onboardingComplete,
  familyMembersAdded,
  aiMonitoringEnabled,
  emergencyContactsUsed,
  darkModeToggled,
}

/// Feature unlock configuration
class FeatureConfig {
  final FeatureId id;
  final String name;
  final String description;
  final String icon;
  final UnlockCondition condition;
  final int threshold; // Number of times condition must be met
  final int unlockScore; // Points awarded on unlock

  const FeatureConfig({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.condition,
    required this.threshold,
    required this.unlockScore,
  });
}

/// Feature unlock state
class FeatureUnlockState {
  final FeatureId featureId;
  final bool isUnlocked;
  final DateTime? unlockedAt;
  final int progressCount; // Current progress toward threshold
  final int threshold; // Required count to unlock

  FeatureUnlockState({
    required this.featureId,
    required this.isUnlocked,
    this.unlockedAt,
    this.progressCount = 0,
    this.threshold = 1,
  });

  Map<String, dynamic> toJson() => {
        'featureId': featureId.name,
        'isUnlocked': isUnlocked,
        'unlockedAt': unlockedAt?.toIso8601String(),
        'progressCount': progressCount,
        'threshold': threshold,
      };

  factory FeatureUnlockState.fromJson(Map<String, dynamic> json) {
    return FeatureUnlockState(
      featureId: FeatureId.values.firstWhere(
        (e) => e.name == json['featureId'],
        orElse: () => FeatureId.dashboard,
      ),
      isUnlocked: json['isUnlocked'] ?? false,
      unlockedAt: json['unlockedAt'] != null
          ? DateTime.parse(json['unlockedAt'])
          : null,
      progressCount: json['progressCount'] ?? 0,
      threshold: json['threshold'] ?? 1,
    );
  }

  double get progressPercentage => progressCount / threshold;
}

/// Login streak data
class LoginStreak {
  final int consecutiveDays;
  final DateTime? lastLoginDate;

  const LoginStreak({
    this.consecutiveDays = 0,
    this.lastLoginDate,
  });

  Map<String, dynamic> toJson() => {
        'consecutiveDays': consecutiveDays,
        'lastLoginDate': lastLoginDate?.toIso8601String(),
      };

  factory LoginStreak.fromJson(Map<String, dynamic> json) {
    return LoginStreak(
      consecutiveDays: json['consecutiveDays'] ?? 0,
      lastLoginDate: json['lastLoginDate'] != null
          ? DateTime.parse(json['lastLoginDate'])
          : null,
    );
  }
}

/// Service for managing progressive feature reveals
class FeatureUnlockService extends ChangeNotifier {
  static final FeatureUnlockService _instance = FeatureUnlockService._internal();
  factory FeatureUnlockService() => _instance;
  FeatureUnlockService._internal() {
    _listenAuthChanges();
  }

  // Feature configurations
  static const Map<FeatureId, FeatureConfig> _featureConfigs = {
    FeatureId.dashboard: FeatureConfig(
      id: FeatureId.dashboard,
      name: 'Dashboard',
      description: 'Your family overview',
      icon: '🏠',
      condition: UnlockCondition.onboardingComplete,
      threshold: 1,
      unlockScore: 0, // Default unlocked
    ),
    FeatureId.family: FeatureConfig(
      id: FeatureId.family,
      name: 'Family',
      description: 'Manage family members',
      icon: '👨‍👩‍👧‍👦',
      condition: UnlockCondition.onboardingComplete,
      threshold: 1,
      unlockScore: 0, // Default unlocked
    ),
    FeatureId.safety: FeatureConfig(
      id: FeatureId.safety,
      name: 'Safety',
      description: 'Emergency features',
      icon: '🚨',
      condition: UnlockCondition.onboardingComplete,
      threshold: 1,
      unlockScore: 0, // Default unlocked
    ),
    FeatureId.settings: FeatureConfig(
      id: FeatureId.settings,
      name: 'Settings',
      description: 'App preferences',
      icon: '⚙️',
      condition: UnlockCondition.onboardingComplete,
      threshold: 1,
      unlockScore: 0, // Default unlocked
    ),
    FeatureId.help: FeatureConfig(
      id: FeatureId.help,
      name: 'Help',
      description: 'Get support',
      icon: '❓',
      condition: UnlockCondition.onboardingComplete,
      threshold: 1,
      unlockScore: 0, // Default unlocked
    ),
    FeatureId.places: FeatureConfig(
      id: FeatureId.places,
      name: 'Places',
      description: 'Geofences and locations',
      icon: '📍',
      condition: UnlockCondition.onboardingComplete,
      threshold: 1,
      unlockScore: 10,
    ),
    FeatureId.circles: FeatureConfig(
      id: FeatureId.circles,
      name: 'Circles',
      description: 'Manage family circles',
      icon: '⭕',
      condition: UnlockCondition.familyMembersAdded,
      threshold: 3,
      unlockScore: 15,
    ),
    FeatureId.behavioralInsights: FeatureConfig(
      id: FeatureId.behavioralInsights,
      name: 'Behavioral Insights',
      description: 'AI-powered patterns',
      icon: '🧠',
      condition: UnlockCondition.aiMonitoringEnabled,
      threshold: 7, // 7 days
      unlockScore: 20,
    ),
    FeatureId.advancedEmergency: FeatureConfig(
      id: FeatureId.advancedEmergency,
      name: 'Advanced Emergency',
      description: 'Enhanced safety features',
      icon: '🆘',
      condition: UnlockCondition.emergencyContactsUsed,
      threshold: 1,
      unlockScore: 15,
    ),
    FeatureId.themeCustomization: FeatureConfig(
      id: FeatureId.themeCustomization,
      name: 'Theme Customization',
      description: 'Personalize your app',
      icon: '🎨',
      condition: UnlockCondition.darkModeToggled,
      threshold: 3,
      unlockScore: 10,
    ),
  };

  final Map<FeatureId, FeatureUnlockState> _unlockStates = {};
  int _totalScore = 0;
  StreamSubscription? _firestoreSubscription;
  StreamSubscription<User?>? _authSubscription;
  LoginStreak _loginStreak = const LoginStreak();

  void _listenAuthChanges() {
    try {
      _authSubscription?.cancel();
      _authSubscription =
          FirebaseAuth.instance.authStateChanges().listen((User? user) {
        if (user == null) {
          _firestoreSubscription?.cancel();
          _firestoreSubscription = null;
        }
      });
    } catch (_) {
      // Firebase not initialized in unit tests
    }
  }

  // Getters
  Map<FeatureId, FeatureUnlockState> get unlockStates => _unlockStates;
  int get totalScore => _totalScore;
  int get maxScore =>
      _featureConfigs.values.fold(0, (accumulated, config) => accumulated + config.unlockScore);
  double get progressPercentage => maxScore > 0 ? _totalScore / maxScore : 0.0;
  LoginStreak get loginStreak => _loginStreak;
  int get consecutiveLoginDays => _loginStreak.consecutiveDays;

  /// Initialize the service
  Future<void> initialize() async {
    try {
      await _loadUnlockStates();
      await _loadLoginStreak();
      _listenToProgress();

      if (kDebugMode) {
        debugPrint('FeatureUnlockService initialized');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error initializing FeatureUnlockService: $e');
      }
    }
  }

  /// Check if a feature is unlocked
  bool isFeatureUnlocked(FeatureId featureId) {
    return _unlockStates[featureId]?.isUnlocked ?? false;
  }

  /// Get unlock state for a feature
  FeatureUnlockState? getFeatureState(FeatureId featureId) {
    return _unlockStates[featureId];
  }

  /// Get feature configuration
  FeatureConfig? getFeatureConfig(FeatureId featureId) {
    return _featureConfigs[featureId];
  }

  /// Get all locked features
  List<FeatureId> getLockedFeatures() {
    return _unlockStates.entries
        .where((entry) => !entry.value.isUnlocked)
        .map((entry) => entry.key)
        .toList();
  }

  /// Get all unlocked features
  List<FeatureId> getUnlockedFeatures() {
    return _unlockStates.entries
        .where((entry) => entry.value.isUnlocked)
        .map((entry) => entry.key)
        .toList();
  }

  /// Record progress toward an unlock condition
  Future<void> recordProgress(UnlockCondition condition) async {
    try {
      final affectedFeatures = _featureConfigs.entries
          .where((entry) => entry.value.condition == condition)
          .map((entry) => entry.key)
          .toList();

      for (final featureId in affectedFeatures) {
        final currentState = _unlockStates[featureId];
        if (currentState == null || currentState.isUnlocked) continue;

        final config = _featureConfigs[featureId]!;
        final newProgress = currentState.progressCount + 1;

        if (newProgress >= config.threshold) {
          // Unlock the feature!
          await _unlockFeature(featureId);
        } else {
          // Update progress
          final updatedState = FeatureUnlockState(
            featureId: featureId,
            isUnlocked: false,
            progressCount: newProgress,
            threshold: config.threshold,
          );

          _unlockStates[featureId] = updatedState;
          await _saveUnlockState(featureId, updatedState);
        }
      }

      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error recording progress: $e');
      }
    }
  }

  /// Unlock a feature
  Future<void> _unlockFeature(FeatureId featureId) async {
    try {
      final config = _featureConfigs[featureId]!;
      final unlockedState = FeatureUnlockState(
        featureId: featureId,
        isUnlocked: true,
        unlockedAt: DateTime.now(),
        progressCount: config.threshold,
        threshold: config.threshold,
      );

      _unlockStates[featureId] = unlockedState;
      _totalScore += config.unlockScore;

      await _saveUnlockState(featureId, unlockedState);
      await _saveAchievement(featureId);

      if (kDebugMode) {
        debugPrint('🎉 Feature unlocked: ${config.name}');
      }

      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error unlocking feature: $e');
      }
    }
  }

  /// Load unlock states from Firestore
  Future<void> _loadUnlockStates() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Initialize all features
      for (final config in _featureConfigs.values) {
        _unlockStates[config.id] = FeatureUnlockState(
          featureId: config.id,
          isUnlocked: config.unlockScore == 0, // Auto-unlock default features
          unlockedAt: config.unlockScore == 0 ? DateTime.now() : null,
          progressCount: 0,
          threshold: config.threshold,
        );
      }

      // Load saved progress
      final progressDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('achievements')
          .doc('feature_progress')
          .get();

      if (progressDoc.exists) {
        final data = progressDoc.data()!;
        final unlockedFeatures = List<String>.from(data['unlockedFeatures'] ?? []);
        final progressData = data['progress'] as Map<String, dynamic>? ?? {};

        for (final featureIdStr in unlockedFeatures) {
          final featureId = FeatureId.values.firstWhere(
            (e) => e.name == featureIdStr,
            orElse: () => FeatureId.dashboard,
          );

          _unlockStates[featureId] = FeatureUnlockState(
            featureId: featureId,
            isUnlocked: true,
            unlockedAt: progressData[featureIdStr]?['unlockedAt'] != null
                ? DateTime.parse(progressData[featureIdStr]['unlockedAt'])
                : null,
            progressCount: _featureConfigs[featureId]!.threshold,
            threshold: _featureConfigs[featureId]!.threshold,
          );
        }

        _totalScore = data['totalUnlockScore'] ?? 0;
      }

      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error loading unlock states: $e');
      }
    }
  }

  /// Save unlock state to Firestore
  Future<void> _saveUnlockState(FeatureId featureId, FeatureUnlockState state) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('achievements')
          .doc('feature_progress');

      await docRef.set({
        'unlockedFeatures': FieldValue.arrayUnion(
          state.isUnlocked ? [featureId.name] : [],
        ),
        'progress.${featureId.name}': state.toJson(),
        'totalUnlockScore': _totalScore,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error saving unlock state: $e');
      }
    }
  }

  /// Save achievement record
  Future<void> _saveAchievement(FeatureId featureId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final config = _featureConfigs[featureId]!;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('achievements')
          .doc('unlocks')
          .collection('history')
          .add({
        'featureId': featureId.name,
        'featureName': config.name,
        'score': config.unlockScore,
        'unlockedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error saving achievement: $e');
      }
    }
  }

  /// Listen to real-time progress updates
  void _listenToProgress() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _firestoreSubscription?.cancel();
      _firestoreSubscription = null;
      return;
    }

    _firestoreSubscription?.cancel();
    _firestoreSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('achievements')
        .doc('feature_progress')
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        _loadUnlockStates(); // Reload on changes
      }
    }, onError: (_) {});
  }

  /// Helper methods for recording specific conditions
  Future<void> recordOnboardingComplete() async {
    await recordProgress(UnlockCondition.onboardingComplete);
  }

  Future<void> recordFamilyMemberAdded() async {
    await recordProgress(UnlockCondition.familyMembersAdded);
  }

  Future<void> recordAiMonitoringDay() async {
    await recordProgress(UnlockCondition.aiMonitoringEnabled);
  }

  Future<void> recordEmergencyContactUsed() async {
    await recordProgress(UnlockCondition.emergencyContactsUsed);
  }

  Future<void> recordDarkModeToggled() async {
    await recordProgress(UnlockCondition.darkModeToggled);
  }

  /// Record a login and update streak
  Future<void> recordLogin() async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      
      if (_loginStreak.lastLoginDate != null) {
        final lastDate = DateTime(
          _loginStreak.lastLoginDate!.year,
          _loginStreak.lastLoginDate!.month,
          _loginStreak.lastLoginDate!.day,
        );
        
        final difference = today.difference(lastDate).inDays;
        
        if (difference == 0) {
          // Same day, no update needed
          return;
        } else if (difference == 1) {
          // Consecutive day - increment streak
          _loginStreak = LoginStreak(
            consecutiveDays: _loginStreak.consecutiveDays + 1,
            lastLoginDate: now,
          );
        } else {
          // Streak broken - reset to 1
          _loginStreak = LoginStreak(
            consecutiveDays: 1,
            lastLoginDate: now,
          );
        }
      } else {
        // First login ever
        _loginStreak = LoginStreak(
          consecutiveDays: 1,
          lastLoginDate: now,
        );
      }
      
      await _saveLoginStreak();
      notifyListeners();
      
      if (kDebugMode) {
        debugPrint('🔥 Login streak: ${_loginStreak.consecutiveDays} days');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error recording login: $e');
      }
    }
  }

  /// Load login streak from Firestore
  Future<void> _loadLoginStreak() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('achievements')
          .doc('login_streak')
          .get();

      if (doc.exists) {
        _loginStreak = LoginStreak.fromJson(doc.data()!);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error loading login streak: $e');
      }
    }
  }

  /// Save login streak to Firestore
  Future<void> _saveLoginStreak() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('achievements')
          .doc('login_streak')
          .set({
        ..._loginStreak.toJson(),
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error saving login streak: $e');
      }
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _firestoreSubscription?.cancel();
    super.dispose();
  }
}
