import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

/// Sensory profile for neurodivergent users
class SensoryProfile {
  final bool reduceMotion;
  final bool quietMode;
  final bool highContrast;
  final double stimulationLevel; // 0.0 = calm, 1.0 = energetic
  final bool breathingSpace;
  final bool darkAcademiaMode;
  final bool breakRemindersEnabled;
  final int breakInterval; // minutes
  final bool largeText; // Elderly mode large text
  final int? familyMemberAge; // Age used to auto-configure profile

  const SensoryProfile({
    this.reduceMotion = false,
    this.quietMode = false,
    this.highContrast = false,
    this.stimulationLevel = 0.5,
    this.breathingSpace = false,
    this.darkAcademiaMode = false,
    this.breakRemindersEnabled = false,
    this.breakInterval = 10,
    this.largeText = false,
    this.familyMemberAge,
  });

  Map<String, dynamic> toJson() => {
        'reduceMotion': reduceMotion,
        'quietMode': quietMode,
        'highContrast': highContrast,
        'stimulationLevel': stimulationLevel,
        'breathingSpace': breathingSpace,
        'darkAcademiaMode': darkAcademiaMode,
        'breakRemindersEnabled': breakRemindersEnabled,
        'breakInterval': breakInterval,
        'largeText': largeText,
        'familyMemberAge': familyMemberAge,
      };

  factory SensoryProfile.fromJson(Map<String, dynamic> json) {
    return SensoryProfile(
      reduceMotion: json['reduceMotion'] ?? false,
      quietMode: json['quietMode'] ?? false,
      highContrast: json['highContrast'] ?? false,
      stimulationLevel: (json['stimulationLevel'] ?? 0.5).toDouble(),
      breathingSpace: json['breathingSpace'] ?? false,
      darkAcademiaMode: json['darkAcademiaMode'] ?? false,
      breakRemindersEnabled: json['breakRemindersEnabled'] ?? false,
      breakInterval: json['breakInterval'] ?? 10,
      largeText: json['largeText'] ?? false,
      familyMemberAge: json['familyMemberAge'] as int?,
    );
  }

  SensoryProfile copyWith({
    bool? reduceMotion,
    bool? quietMode,
    bool? highContrast,
    double? stimulationLevel,
    bool? breathingSpace,
    bool? darkAcademiaMode,
    bool? breakRemindersEnabled,
    int? breakInterval,
    bool? largeText,
    int? familyMemberAge,
  }) {
    return SensoryProfile(
      reduceMotion: reduceMotion ?? this.reduceMotion,
      quietMode: quietMode ?? this.quietMode,
      highContrast: highContrast ?? this.highContrast,
      stimulationLevel: stimulationLevel ?? this.stimulationLevel,
      breathingSpace: breathingSpace ?? this.breathingSpace,
      darkAcademiaMode: darkAcademiaMode ?? this.darkAcademiaMode,
      breakRemindersEnabled: breakRemindersEnabled ?? this.breakRemindersEnabled,
      breakInterval: breakInterval ?? this.breakInterval,
      largeText: largeText ?? this.largeText,
      familyMemberAge: familyMemberAge ?? this.familyMemberAge,
    );
  }

  /// Create a profile auto-configured based on age
  static SensoryProfile forAge(int age) {
    if (age < 25) {
      // Young / dopamine-fried profile
      return const SensoryProfile(
        stimulationLevel: 0.9,
        reduceMotion: true,
        highContrast: true,
      );
    } else if (age > 60) {
      // Elderly profile
      return const SensoryProfile(
        stimulationLevel: 0.2,
        largeText: true,
        breathingSpace: true,
      );
    } else {
      // Default profile
      return const SensoryProfile(
        stimulationLevel: 0.5,
      );
    }
  }

  /// Quick comfort mode presets
  static SensoryProfile calmMode() {
    return const SensoryProfile(
      reduceMotion: true,
      quietMode: true,
      stimulationLevel: 0.2,
      breathingSpace: true,
    );
  }

  static SensoryProfile focusMode() {
    return const SensoryProfile(
      highContrast: true,
      stimulationLevel: 0.6,
      quietMode: true,
    );
  }

  static SensoryProfile energyMode() {
    return const SensoryProfile(
      stimulationLevel: 1.0,
      reduceMotion: false,
      quietMode: false,
    );
  }
}

/// Service for managing sensory regulation and accessibility
class SensoryRegulationService extends ChangeNotifier {
  static final SensoryRegulationService _instance =
      SensoryRegulationService._internal();
  factory SensoryRegulationService() => _instance;
  SensoryRegulationService._internal() {
    _listenAuthChanges();
  }

  SensoryProfile _profile = const SensoryProfile();
  Timer? _breakReminderTimer;
  StreamSubscription? _profileSubscription;
  StreamSubscription<User?>? _authSubscription;
  bool _calmModeActive = false;

  void _listenAuthChanges() {
    try {
      _authSubscription?.cancel();
      _authSubscription =
          FirebaseAuth.instance.authStateChanges().listen((User? user) {
        if (user == null) {
          _profileSubscription?.cancel();
          _profileSubscription = null;
          _breakReminderTimer?.cancel();
          _breakReminderTimer = null;
        }
      });
    } catch (_) {
      // Firebase not initialized in unit tests
    }
  }

  // Getters
  SensoryProfile get profile => _profile;
  bool get calmModeActive => _calmModeActive;

  // Computed properties based on stimulation level
  double get animationSpeedMultiplier {
    if (_profile.reduceMotion) return 0.5; // 2x slower
    return 1.0 - (_profile.stimulationLevel * 0.3); // 0.7 to 1.0
  }

  double get contrastBoost {
    if (_profile.highContrast) return 1.3; // 30% boost
    return 1.0;
  }

  double get paddingMultiplier {
    if (_profile.breathingSpace) return 1.5;
    return 1.0;
  }

  bool get shouldUseHaptics {
    return !_profile.quietMode;
  }

  bool get shouldUseBiophilicDesign {
    return _profile.stimulationLevel < 0.5;
  }

  /// Initialize the service
  Future<void> initialize() async {
    try {
      await _loadProfile();
      _listenToProfileChanges();
      _scheduleBreakReminders();

      if (kDebugMode) {
        debugPrint('SensoryRegulationService initialized');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error initializing SensoryRegulationService: $e');
      }
    }
  }

  /// Load sensory profile from Firestore
  Future<void> _loadProfile() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('settings')
          .doc('sensory_profile')
          .get();

      if (doc.exists) {
        _profile = SensoryProfile.fromJson(doc.data()!);
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error loading sensory profile: $e');
      }
    }
  }

  /// Listen to real-time profile changes
  void _listenToProfileChanges() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _profileSubscription?.cancel();
      _profileSubscription = null;
      return;
    }

    _profileSubscription?.cancel();
    _profileSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('settings')
        .doc('sensory_profile')
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        _profile = SensoryProfile.fromJson(snapshot.data()!);
        notifyListeners();
        _scheduleBreakReminders(); // Reschedule if interval changed
      }
    }, onError: (_) {});
  }

  /// Save sensory profile to Firestore
  Future<void> updateProfile(SensoryProfile newProfile) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('settings')
          .doc('sensory_profile')
          .set(newProfile.toJson(), SetOptions(merge: true));

      _profile = newProfile;
      notifyListeners();
      _scheduleBreakReminders();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error updating sensory profile: $e');
      }
    }
  }

  /// Update specific profile settings
  Future<void> setReduceMotion(bool enabled) async {
    await updateProfile(_profile.copyWith(reduceMotion: enabled));
  }

  Future<void> setQuietMode(bool enabled) async {
    await updateProfile(_profile.copyWith(quietMode: enabled));
  }

  Future<void> setHighContrast(bool enabled) async {
    await updateProfile(_profile.copyWith(highContrast: enabled));
  }

  Future<void> setStimulationLevel(double level) async {
    await updateProfile(_profile.copyWith(stimulationLevel: level.clamp(0.0, 1.0)));
  }

  Future<void> setBreathingSpace(bool enabled) async {
    await updateProfile(_profile.copyWith(breathingSpace: enabled));
  }

  Future<void> setDarkAcademiaMode(bool enabled) async {
    await updateProfile(_profile.copyWith(darkAcademiaMode: enabled));
  }

  Future<void> setBreakReminders(bool enabled, {int? interval}) async {
    await updateProfile(_profile.copyWith(
      breakRemindersEnabled: enabled,
      breakInterval: interval,
    ));
  }

  Future<void> setLargeText(bool enabled) async {
    await updateProfile(_profile.copyWith(largeText: enabled));
  }

  /// Apply age-based sensory profile
  Future<void> applyAgeBasedProfile(int age) async {
    final ageProfile = SensoryProfile.forAge(age);
    await updateProfile(_profile.copyWith(
      stimulationLevel: ageProfile.stimulationLevel,
      reduceMotion: ageProfile.reduceMotion,
      highContrast: ageProfile.highContrast,
      largeText: ageProfile.largeText,
      breathingSpace: ageProfile.breathingSpace,
      familyMemberAge: age,
    ));
    // Ensure UI rebuilds immediately after age profile is applied
    notifyListeners();
  }

  /// Quick comfort mode presets
  Future<void> applyCalmMode() async {
    await updateProfile(SensoryProfile.calmMode());
  }

  Future<void> applyFocusMode() async {
    await updateProfile(SensoryProfile.focusMode());
  }

  Future<void> applyEnergyMode() async {
    await updateProfile(SensoryProfile.energyMode());
  }

  /// Emergency calm mode - strips UI to essentials
  void activateCalmMode() {
    _calmModeActive = true;
    notifyListeners();
  }

  void deactivateCalmMode() {
    _calmModeActive = false;
    notifyListeners();
  }

  /// Schedule break reminders
  void _scheduleBreakReminders() {
    _breakReminderTimer?.cancel();

    if (!_profile.breakRemindersEnabled) return;

    final intervalMinutes = _profile.breakInterval;
    _breakReminderTimer = Timer.periodic(
      Duration(minutes: intervalMinutes),
      (_) => _sendBreakReminder(),
    );
  }

  /// Send gentle break reminder
  void _sendBreakReminder() {
    // This will be handled by notification system
    if (kDebugMode) {
      debugPrint('🧘 Break reminder: Take a moment to rest');
    }
  }

  /// Get animation duration based on sensory profile
  Duration getAnimationDuration(Duration baseDuration) {
    if (_profile.reduceMotion) {
      return baseDuration * 2; // 2x slower
    }
    return baseDuration;
  }

  /// Get text color with contrast boost
  double getTextOpacity(double baseOpacity) {
    if (_profile.highContrast) {
      return (baseOpacity * 1.3).clamp(0.0, 1.0);
    }
    return baseOpacity;
  }

  /// Get padding based on breathing space
  double getPadding(double basePadding) {
    if (_profile.breathingSpace) {
      return basePadding * 1.5;
    }
    return basePadding;
  }

  /// Determine if biophilic design should be used
  bool useBiophilicDesign() {
    return _profile.stimulationLevel < 0.5;
  }

  /// Get sensory-appropriate animation curve
  Curve getAnimationCurve() {
    if (_profile.reduceMotion) {
      return Curves.easeInOut; // Gentle
    }
    return Curves.easeInOutSine; // Organic
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _breakReminderTimer?.cancel();
    _profileSubscription?.cancel();
    super.dispose();
  }
}
