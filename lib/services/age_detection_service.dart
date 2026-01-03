import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

/// Age categories for user classification
enum AgeCategory {
  young, // 18-40
  middleAged, // 41-64
  elderly, // 65+
}

/// Result of age detection analysis
class AgeDetectionResult {
  final AgeCategory category;
  final double confidence; // 0.0 to 1.0
  final Map<String, dynamic> metrics;
  final DateTime timestamp;

  AgeDetectionResult({
    required this.category,
    required this.confidence,
    required this.metrics,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'category': category.name,
        'confidence': confidence,
        'metrics': metrics,
        'timestamp': timestamp.toIso8601String(),
      };

  factory AgeDetectionResult.fromJson(Map<String, dynamic> json) {
    return AgeDetectionResult(
      category: AgeCategory.values.firstWhere(
        (e) => e.name == json['category'],
        orElse: () => AgeCategory.young,
      ),
      confidence: (json['confidence'] ?? 0.0).toDouble(),
      metrics: json['metrics'] ?? {},
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}

/// Usage pattern data point
class UsagePattern {
  final DateTime timestamp;
  final double sessionDuration; // in minutes
  final double tapFrequency; // taps per minute
  final double errorRate; // percentage of misclicks
  final double gestureSpeed; // seconds per gesture
  final double scrollSpeed; // pixels per second

  UsagePattern({
    required this.timestamp,
    required this.sessionDuration,
    required this.tapFrequency,
    required this.errorRate,
    required this.gestureSpeed,
    required this.scrollSpeed,
  });

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'sessionDuration': sessionDuration,
        'tapFrequency': tapFrequency,
        'errorRate': errorRate,
        'gestureSpeed': gestureSpeed,
        'scrollSpeed': scrollSpeed,
      };

  factory UsagePattern.fromJson(Map<String, dynamic> json) {
    return UsagePattern(
      timestamp: DateTime.parse(json['timestamp']),
      sessionDuration: (json['sessionDuration'] ?? 0.0).toDouble(),
      tapFrequency: (json['tapFrequency'] ?? 0.0).toDouble(),
      errorRate: (json['errorRate'] ?? 0.0).toDouble(),
      gestureSpeed: (json['gestureSpeed'] ?? 0.0).toDouble(),
      scrollSpeed: (json['scrollSpeed'] ?? 0.0).toDouble(),
    );
  }
}

/// Service for detecting user age based on interaction patterns
class AgeDetectionService extends ChangeNotifier {
  static final AgeDetectionService _instance = AgeDetectionService._internal();
  factory AgeDetectionService() => _instance;
  AgeDetectionService._internal();

  // Session tracking
  DateTime? _sessionStart;
  int _tapCount = 0;
  int _errorCount = 0;
  final List<double> _gestureSpeeds = [];
  final List<double> _scrollSpeeds = [];

  // Analysis state
  AgeDetectionResult? _currentResult;
  final List<UsagePattern> _recentPatterns = [];
  Timer? _analyticsTimer;

  // Configuration
  static const int _analysisWindowDays = 7;
  static const double _confidenceThreshold = 0.7;
  static const int _minPatternsForAnalysis = 5;

  // Getters
  AgeDetectionResult? get currentResult => _currentResult;
  bool get isElderlyMode =>
      _currentResult != null &&
      _currentResult!.category == AgeCategory.elderly &&
      _currentResult!.confidence >= _confidenceThreshold;

  /// Initialize the service
  Future<void> initialize() async {
    try {
      await _loadStoredAnalytics();
      _startSessionTracking();
      _schedulePeriodicAnalysis();
      if (kDebugMode) {
        debugPrint('AgeDetectionService initialized');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error initializing AgeDetectionService: $e');
      }
    }
  }

  /// Start tracking a new session
  void startSession() {
    _sessionStart = DateTime.now();
    _tapCount = 0;
    _errorCount = 0;
    _gestureSpeeds.clear();
    _scrollSpeeds.clear();
  }

  /// End current session and record metrics
  Future<void> endSession() async {
    if (_sessionStart == null) return;

    final duration = DateTime.now().difference(_sessionStart!).inMinutes;
    if (duration < 1) return; // Ignore very short sessions

    final pattern = UsagePattern(
      timestamp: DateTime.now(),
      sessionDuration: duration.toDouble(),
      tapFrequency: _tapCount / duration,
      errorRate: _tapCount > 0 ? (_errorCount / _tapCount) * 100 : 0,
      gestureSpeed: _gestureSpeeds.isNotEmpty
          ? _gestureSpeeds.reduce((a, b) => a + b) / _gestureSpeeds.length
          : 0,
      scrollSpeed: _scrollSpeeds.isNotEmpty
          ? _scrollSpeeds.reduce((a, b) => a + b) / _scrollSpeeds.length
          : 0,
    );

    await _saveUsagePattern(pattern);
    _recentPatterns.add(pattern);

    // Keep only recent patterns in memory
    if (_recentPatterns.length > 50) {
      _recentPatterns.removeAt(0);
    }

    // Trigger analysis if we have enough data
    if (_recentPatterns.length >= _minPatternsForAnalysis) {
      await analyzeUsagePatterns();
    }

    _sessionStart = null;
  }

  /// Record a tap interaction
  void recordTap({bool wasError = false}) {
    _tapCount++;
    if (wasError) {
      _errorCount++;
    }
  }

  /// Record a gesture with its duration
  void recordGesture(Duration duration) {
    _gestureSpeeds.add(duration.inMilliseconds / 1000.0);
  }

  /// Record scroll speed
  void recordScroll(double pixelsPerSecond) {
    _scrollSpeeds.add(pixelsPerSecond);
  }

  /// Analyze collected usage patterns and classify user age
  Future<AgeDetectionResult> analyzeUsagePatterns() async {
    if (_recentPatterns.length < _minPatternsForAnalysis) {
      return AgeDetectionResult(
        category: AgeCategory.young,
        confidence: 0.0,
        metrics: {'error': 'Insufficient data'},
      );
    }

    // Calculate average metrics over the analysis window
    final recent = _recentPatterns
        .where((p) => DateTime.now().difference(p.timestamp).inDays <= _analysisWindowDays)
        .toList();

    if (recent.isEmpty) {
      return AgeDetectionResult(
        category: AgeCategory.young,
        confidence: 0.0,
        metrics: {'error': 'No recent data'},
      );
    }

    final avgSessionDuration =
        recent.map((p) => p.sessionDuration).reduce((a, b) => a + b) / recent.length;
    final avgTapFrequency =
        recent.map((p) => p.tapFrequency).reduce((a, b) => a + b) / recent.length;
    final avgErrorRate =
        recent.map((p) => p.errorRate).reduce((a, b) => a + b) / recent.length;
    final avgGestureSpeed =
        recent.map((p) => p.gestureSpeed).reduce((a, b) => a + b) / recent.length;
    final avgScrollSpeed =
        recent.map((p) => p.scrollSpeed).reduce((a, b) => a + b) / recent.length;

    // ML-based classification scoring
    final scores = _calculateCategoryScores(
      sessionDuration: avgSessionDuration,
      tapFrequency: avgTapFrequency,
      errorRate: avgErrorRate,
      gestureSpeed: avgGestureSpeed,
      scrollSpeed: avgScrollSpeed,
    );

    // Find category with highest score
    AgeCategory bestCategory = AgeCategory.young;
    double maxScore = 0.0;

    scores.forEach((category, score) {
      if (score > maxScore) {
        maxScore = score;
        bestCategory = category;
      }
    });

    final result = AgeDetectionResult(
      category: bestCategory,
      confidence: maxScore,
      metrics: {
        'avgSessionDuration': avgSessionDuration,
        'avgTapFrequency': avgTapFrequency,
        'avgErrorRate': avgErrorRate,
        'avgGestureSpeed': avgGestureSpeed,
        'avgScrollSpeed': avgScrollSpeed,
        'sampleSize': recent.length,
        'scores': scores.map((k, v) => MapEntry(k.name, v)),
      },
    );

    _currentResult = result;
    await _saveAnalysisResult(result);
    notifyListeners();

    if (kDebugMode) {
      debugPrint('Age detection: ${result.category.name} (${(result.confidence * 100).toStringAsFixed(1)}%)');
    }

    return result;
  }

  /// Calculate probability scores for each age category
  Map<AgeCategory, double> _calculateCategoryScores({
    required double sessionDuration,
    required double tapFrequency,
    required double errorRate,
    required double gestureSpeed,
    required double scrollSpeed,
  }) {
    // Normalized feature scores (0-1) based on observed patterns
    
    // Elderly patterns: 2-5 min sessions, 15-25 taps/min, 15-30% errors, 1-2 sec gestures
    final elderlyScore = _calculateFeatureScore(
      sessionDuration: sessionDuration,
      tapFrequency: tapFrequency,
      errorRate: errorRate,
      gestureSpeed: gestureSpeed,
      scrollSpeed: scrollSpeed,
      targetSessionRange: [2.0, 5.0],
      targetTapRange: [15.0, 25.0],
      targetErrorRange: [15.0, 30.0],
      targetGestureRange: [1.0, 2.0],
      targetScrollRange: [50.0, 150.0], // Slow scrolling
    );

    // Young patterns: 10-30 min sessions, 40-80 taps/min, <5% errors, 0.3-0.7 sec gestures
    final youngScore = _calculateFeatureScore(
      sessionDuration: sessionDuration,
      tapFrequency: tapFrequency,
      errorRate: errorRate,
      gestureSpeed: gestureSpeed,
      scrollSpeed: scrollSpeed,
      targetSessionRange: [10.0, 30.0],
      targetTapRange: [40.0, 80.0],
      targetErrorRange: [0.0, 5.0],
      targetGestureRange: [0.3, 0.7],
      targetScrollRange: [300.0, 800.0], // Fast scrolling
    );

    // Middle-aged patterns: 5-15 min sessions, 25-45 taps/min, 5-15% errors, 0.7-1.2 sec gestures
    final middleAgedScore = _calculateFeatureScore(
      sessionDuration: sessionDuration,
      tapFrequency: tapFrequency,
      errorRate: errorRate,
      gestureSpeed: gestureSpeed,
      scrollSpeed: scrollSpeed,
      targetSessionRange: [5.0, 15.0],
      targetTapRange: [25.0, 45.0],
      targetErrorRange: [5.0, 15.0],
      targetGestureRange: [0.7, 1.2],
      targetScrollRange: [150.0, 300.0],
    );

    return {
      AgeCategory.elderly: elderlyScore,
      AgeCategory.young: youngScore,
      AgeCategory.middleAged: middleAgedScore,
    };
  }

  /// Calculate feature matching score for a target profile
  double _calculateFeatureScore({
    required double sessionDuration,
    required double tapFrequency,
    required double errorRate,
    required double gestureSpeed,
    required double scrollSpeed,
    required List<double> targetSessionRange,
    required List<double> targetTapRange,
    required List<double> targetErrorRange,
    required List<double> targetGestureRange,
    required List<double> targetScrollRange,
  }) {
    double score = 0.0;
    int weights = 0;

    // Session duration score (weight: 2)
    score += _inRangeScore(sessionDuration, targetSessionRange) * 2;
    weights += 2;

    // Tap frequency score (weight: 3)
    score += _inRangeScore(tapFrequency, targetTapRange) * 3;
    weights += 3;

    // Error rate score (weight: 3)
    score += _inRangeScore(errorRate, targetErrorRange) * 3;
    weights += 3;

    // Gesture speed score (weight: 2)
    if (gestureSpeed > 0) {
      score += _inRangeScore(gestureSpeed, targetGestureRange) * 2;
      weights += 2;
    }

    // Scroll speed score (weight: 1)
    if (scrollSpeed > 0) {
      score += _inRangeScore(scrollSpeed, targetScrollRange) * 1;
      weights += 1;
    }

    return weights > 0 ? score / weights : 0.0;
  }

  /// Calculate how well a value fits within a target range (0-1)
  double _inRangeScore(double value, List<double> range) {
    if (range.length != 2) return 0.0;

    final min = range[0];
    final max = range[1];
    final center = (min + max) / 2;
    final tolerance = (max - min) / 2;

    if (value >= min && value <= max) {
      // Perfect score if in range
      return 1.0;
    } else {
      // Decay score based on distance from center
      final distance = (value - center).abs();
      final maxDist = tolerance * 3;
      final score = (maxDist > 0) ? (1.0 - (distance / maxDist)).clamp(0.0, 1.0) : 0.0;
      return score;
    }
  }

  /// Save usage pattern to Firestore
  Future<void> _saveUsagePattern(UsagePattern pattern) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('analytics')
          .doc('usage_patterns')
          .collection('patterns')
          .add(pattern.toJson());
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error saving usage pattern: $e');
      }
    }
  }

  /// Save analysis result to Firestore
  Future<void> _saveAnalysisResult(AgeDetectionResult result) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('analytics')
          .doc('age_detection')
          .set(result.toJson(), SetOptions(merge: true));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error saving analysis result: $e');
      }
    }
  }

  /// Load stored analytics from Firestore
  Future<void> _loadStoredAnalytics() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Load recent patterns
      final patternsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('analytics')
          .doc('usage_patterns')
          .collection('patterns')
          .orderBy('timestamp', descending: true)
          .limit(50)
          .get();

      _recentPatterns.clear();
      for (var doc in patternsSnapshot.docs) {
        _recentPatterns.add(UsagePattern.fromJson(doc.data()));
      }

      // Load last analysis result
      final resultDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('analytics')
          .doc('age_detection')
          .get();

      if (resultDoc.exists) {
        _currentResult = AgeDetectionResult.fromJson(resultDoc.data()!);
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error loading stored analytics: $e');
      }
    }
  }

  /// Start session tracking
  void _startSessionTracking() {
    startSession();
  }

  /// Schedule periodic analysis
  void _schedulePeriodicAnalysis() {
    _analyticsTimer?.cancel();
    _analyticsTimer = Timer.periodic(const Duration(hours: 24), (_) {
      analyzeUsagePatterns();
    });
  }

  /// Manually override age category (for testing)
  void setManualCategory(AgeCategory category) {
    _currentResult = AgeDetectionResult(
      category: category,
      confidence: 1.0,
      metrics: {'manual': true},
    );
    notifyListeners();
  }

  @override
  void dispose() {
    _analyticsTimer?.cancel();
    super.dispose();
  }
}
