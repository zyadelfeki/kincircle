import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Coordinates all user-configurable privacy controls, surfacing state via a
/// [ChangeNotifier] so widgets can react instantly to changes.
class PrivacyControlsService extends ChangeNotifier {
  PrivacyControlsService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  PrivacySettings? _settings;
  PrivacySettings? get settings => _settings;

  bool get isLoaded => _settings != null;

  /// Loads the settings document, provisioning defaults when absent.
  Future<void> loadPrivacySettings(String userId) async {
    final DocumentReference<Map<String, dynamic>> ref = _settingsRef(userId);
    final DocumentSnapshot<Map<String, dynamic>> snapshot = await ref.get();
    if (snapshot.exists && snapshot.data() != null) {
      _settings = PrivacySettings.fromMap(snapshot.data()!);
    } else {
      _settings = PrivacySettings.defaults();
      await ref.set(_settings!.toMap());
    }
    notifyListeners();
  }

  /// Persists [settings] and updates the in-memory cache.
  Future<void> savePrivacySettings(
    String userId,
    PrivacySettings settings,
  ) async {
    await _settingsRef(userId).set(settings.toMap());
    _settings = settings;
    await _recordPrivacyEvent(userId, 'settings_saved');
    notifyListeners();
  }

  /// Updates location sharing preferences.
  Future<void> updateLocationSharing({
    required String userId,
    required bool enabled,
    List<String>? allowedFamilyMembers,
    LocationSharingMode? mode,
  }) async {
    final Map<String, dynamic> update = <String, dynamic>{
      'location_sharing_enabled': enabled,
      'last_updated': FieldValue.serverTimestamp(),
    };
    if (allowedFamilyMembers != null) {
      update['allowed_family_members'] = allowedFamilyMembers;
    }
    if (mode != null) {
      update['location_sharing_mode'] = mode.name;
    }
    await _settingsRef(userId).update(update);
    await loadPrivacySettings(userId);
    await _recordPrivacyEvent(userId, 'location_updated');
  }

  /// Sets how many days of historical data should be retained.
  Future<void> setDataRetentionPeriod({
    required String userId,
    required int days,
  }) async {
    await _settingsRef(userId).update(<String, dynamic>{
      'data_retention_days': days,
      'auto_delete_enabled': days > 0,
      'last_updated': FieldValue.serverTimestamp(),
    });
    if (days > 0) {
      await _deleteDataOlderThan(userId, days);
    }
    await loadPrivacySettings(userId);
    await _recordPrivacyEvent(userId, 'retention_updated');
  }

  /// Deletes Firestore history older than [days].
  Future<void> _deleteDataOlderThan(String userId, int days) async {
    final DateTime cutoff = DateTime.now().subtract(Duration(days: days));
    final List<String> collections = <String>[
      'location_history',
      'wellbeing_analytics',
      'companion_history',
    ];
    for (final String name in collections) {
      final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection(name)
          .where('timestamp', isLessThan: cutoff)
          .get();
      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
          in snapshot.docs) {
        await doc.reference.delete();
      }
    }
  }

  /// Toggles analytics participation.
  Future<void> toggleAnalytics({
    required String userId,
    required bool enabled,
  }) async {
    await _settingsRef(userId).update(<String, dynamic>{
      'analytics_enabled': enabled,
      'last_updated': FieldValue.serverTimestamp(),
    });
    await loadPrivacySettings(userId);
    await _recordPrivacyEvent(userId, 'analytics_${enabled ? 'enabled' : 'disabled'}');
  }

  /// Toggles crash reporting participation.
  Future<void> toggleCrashReporting({
    required String userId,
    required bool enabled,
  }) async {
    await _settingsRef(userId).update(<String, dynamic>{
      'crash_reporting_enabled': enabled,
      'last_updated': FieldValue.serverTimestamp(),
    });
    await loadPrivacySettings(userId);
    await _recordPrivacyEvent(userId, 'crash_${enabled ? 'enabled' : 'disabled'}');
  }

  /// Updates AI processing consent.
  Future<void> updateAiProcessing({
    required String userId,
    required bool enabled,
  }) async {
    await _settingsRef(userId).update(<String, dynamic>{
      'ai_processing_enabled': enabled,
      'last_updated': FieldValue.serverTimestamp(),
    });
    await loadPrivacySettings(userId);
    await _recordPrivacyEvent(userId, 'ai_processing_${enabled ? 'enabled' : 'disabled'}');
  }

  /// Controls third-party data sharing (e.g., emergency services, providers).
  Future<void> updateThirdPartySharing({
    required String userId,
    required Map<String, bool> permissions,
  }) async {
    await _settingsRef(userId).update(<String, dynamic>{
      'third_party_sharing': permissions,
      'last_updated': FieldValue.serverTimestamp(),
    });
    await loadPrivacySettings(userId);
    await _recordPrivacyEvent(userId, 'third_party_updated');
  }

  /// Computes a privacy score used by UI surfaces.
  int calculatePrivacyScore() {
    final PrivacySettings? s = _settings;
    if (s == null) return 0;
    int score = 0;
    if (s.autoDeleteEnabled) score += 20;
    if (!s.analyticsEnabled) score += 20;
    if (s.dataRetentionDays <= 90) score += 20;
    if (!s.thirdPartySharing.values.any((bool v) => v)) score += 20;
    if (s.locationSharingMode == LocationSharingMode.familyOnly) score += 20;
    return score.clamp(0, 100);
  }

  Future<void> _recordPrivacyEvent(String userId, String action) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('privacy_events')
        .add(<String, dynamic>{
      'action': action,
      'timestamp': FieldValue.serverTimestamp(),
      'uid': userId,
    });
  }

  DocumentReference<Map<String, dynamic>> _settingsRef(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('privacy')
        .doc('settings');
  }
}

/// Immutable snapshot of privacy preferences.
class PrivacySettings {
  PrivacySettings({
    required this.locationSharingEnabled,
    required this.locationSharingMode,
    required this.allowedFamilyMembers,
    required this.dataRetentionDays,
    required this.autoDeleteEnabled,
    required this.analyticsEnabled,
    required this.crashReportingEnabled,
    required this.thirdPartySharing,
    required this.aiProcessingEnabled,
    required this.lastUpdated,
  });

  final bool locationSharingEnabled;
  final LocationSharingMode locationSharingMode;
  final List<String> allowedFamilyMembers;
  final int dataRetentionDays;
  final bool autoDeleteEnabled;
  final bool analyticsEnabled;
  final bool crashReportingEnabled;
  final Map<String, bool> thirdPartySharing;
  final bool aiProcessingEnabled;
  final DateTime lastUpdated;

  factory PrivacySettings.defaults() {
    return PrivacySettings(
      locationSharingEnabled: true,
      locationSharingMode: LocationSharingMode.familyOnly,
      allowedFamilyMembers: <String>[],
      dataRetentionDays: 90,
      autoDeleteEnabled: true,
      analyticsEnabled: false,
      crashReportingEnabled: true,
      thirdPartySharing: <String, bool>{
        'emergency_services': true,
        'health_providers': false,
        'analytics_partners': false,
      },
      aiProcessingEnabled: true,
      lastUpdated: DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'location_sharing_enabled': locationSharingEnabled,
      'location_sharing_mode': locationSharingMode.name,
      'allowed_family_members': allowedFamilyMembers,
      'data_retention_days': dataRetentionDays,
      'auto_delete_enabled': autoDeleteEnabled,
      'analytics_enabled': analyticsEnabled,
      'crash_reporting_enabled': crashReportingEnabled,
      'third_party_sharing': thirdPartySharing,
      'ai_processing_enabled': aiProcessingEnabled,
      'last_updated': lastUpdated.toIso8601String(),
    };
  }

  factory PrivacySettings.fromMap(Map<String, dynamic> map) {
    return PrivacySettings(
      locationSharingEnabled:
          map['location_sharing_enabled'] as bool? ?? true,
      locationSharingMode: LocationSharingModeX.fromName(
          map['location_sharing_mode'] as String? ?? 'familyOnly'),
      allowedFamilyMembers: List<String>.from(
        map['allowed_family_members'] as List<dynamic>? ?? <dynamic>[],
      ),
      dataRetentionDays: map['data_retention_days'] as int? ?? 90,
      autoDeleteEnabled: map['auto_delete_enabled'] as bool? ?? true,
      analyticsEnabled: map['analytics_enabled'] as bool? ?? false,
      crashReportingEnabled:
          map['crash_reporting_enabled'] as bool? ?? true,
      thirdPartySharing:
          Map<String, bool>.from(map['third_party_sharing'] as Map? ?? <String, bool>{}),
      aiProcessingEnabled: map['ai_processing_enabled'] as bool? ?? true,
      lastUpdated: DateTime.tryParse(map['last_updated'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  PrivacySettings copyWith({
    bool? locationSharingEnabled,
    LocationSharingMode? locationSharingMode,
    List<String>? allowedFamilyMembers,
    int? dataRetentionDays,
    bool? autoDeleteEnabled,
    bool? analyticsEnabled,
    bool? crashReportingEnabled,
    Map<String, bool>? thirdPartySharing,
    bool? aiProcessingEnabled,
    DateTime? lastUpdated,
  }) {
    return PrivacySettings(
      locationSharingEnabled:
          locationSharingEnabled ?? this.locationSharingEnabled,
      locationSharingMode: locationSharingMode ?? this.locationSharingMode,
      allowedFamilyMembers:
          allowedFamilyMembers ?? List<String>.from(this.allowedFamilyMembers),
      dataRetentionDays: dataRetentionDays ?? this.dataRetentionDays,
      autoDeleteEnabled: autoDeleteEnabled ?? this.autoDeleteEnabled,
      analyticsEnabled: analyticsEnabled ?? this.analyticsEnabled,
      crashReportingEnabled:
          crashReportingEnabled ?? this.crashReportingEnabled,
      thirdPartySharing:
          thirdPartySharing ?? Map<String, bool>.from(this.thirdPartySharing),
      aiProcessingEnabled: aiProcessingEnabled ?? this.aiProcessingEnabled,
      lastUpdated: lastUpdated ?? DateTime.now(),
    );
  }
}

enum LocationSharingMode {
  everyone,
  familyOnly,
  selectedMembers,
  emergencyOnly,
  disabled,
}

extension LocationSharingModeX on LocationSharingMode {
  static LocationSharingMode fromName(String name) {
    return LocationSharingMode.values.firstWhere(
      (LocationSharingMode mode) => mode.name == name,
      orElse: () => LocationSharingMode.familyOnly,
    );
  }

  String label() {
    switch (this) {
      case LocationSharingMode.everyone:
        return 'Everyone';
      case LocationSharingMode.familyOnly:
        return 'Family only';
      case LocationSharingMode.selectedMembers:
        return 'Selected members';
      case LocationSharingMode.emergencyOnly:
        return 'Emergency only';
      case LocationSharingMode.disabled:
        return 'Disabled';
    }
  }
}
