import 'package:firebase_remote_config/firebase_remote_config.dart';

class RemoteConfigService {
  static final RemoteConfigService _instance = RemoteConfigService._internal();
  factory RemoteConfigService() => _instance;
  RemoteConfigService._internal();

  late final FirebaseRemoteConfig _remoteConfig;

  Future<void> init() async {
    _remoteConfig = FirebaseRemoteConfig.instance;

    await _remoteConfig.setDefaults(const {
      'smart_alerts_enabled': true,
      'silence_enabled': false,
      'voice_sos_enabled': false,
      'ml_alerts_enabled': false,
      // Telemetry sampling for invite events (0.0..1.0)
      'telemetry_invite_sample_rate': 1.0,
      // Driver Safety feature flags and thresholds
      'driver_safety_enabled': true,
      'driver_safety_threshold_brake': 0.7,
      'driver_safety_threshold_accel': 0.7,
      // Emergency Response feature flags
      'emergency_response_enabled': true,
      'wandering_prediction_enabled': true,
    });

    await _remoteConfig.setConfigSettings(RemoteConfigSettings(
      fetchTimeout: const Duration(seconds: 10),
      minimumFetchInterval: const Duration(hours: 1),
    ));

    await _remoteConfig.fetchAndActivate();
  }

  bool get smartAlertsEnabled => _remoteConfig.getBool('smart_alerts_enabled');
  bool get silenceEnabled => _remoteConfig.getBool('silence_enabled');
  bool get voiceSosEnabled => _remoteConfig.getBool('voice_sos_enabled');
  bool get mlAlertsEnabled => _remoteConfig.getBool('ml_alerts_enabled');
  double get inviteTelemetrySampleRate => _remoteConfig.getDouble('telemetry_invite_sample_rate');
  // Driver Safety flags
  bool get driverSafetyEnabled => _remoteConfig.getBool('driver_safety_enabled');
  double get driverSafetyThresholdBrake => _remoteConfig.getDouble('driver_safety_threshold_brake');
  double get driverSafetyThresholdAccel => _remoteConfig.getDouble('driver_safety_threshold_accel');

  Future<void> setSmartAlertsEnabled(bool enabled) async {
    await _remoteConfig.setDefaults({'smart_alerts_enabled': enabled});
    await _remoteConfig.fetchAndActivate();
  }

  Future<void> setMlAlertsEnabled(bool enabled) async {
    await _remoteConfig.setDefaults({'ml_alerts_enabled': enabled});
    await _remoteConfig.fetchAndActivate();
  }

  Future<void> setSilenceEnabled(bool enabled) async {
    await _remoteConfig.setDefaults({'silence_enabled': enabled});
    await _remoteConfig.fetchAndActivate();
  }

  Future<void> setVoiceSosEnabled(bool enabled) async {
    await _remoteConfig.setDefaults({'voice_sos_enabled': enabled});
    await _remoteConfig.fetchAndActivate();
  }

  Future<void> setInviteTelemetrySampleRate(double rate) async {
    await _remoteConfig.setDefaults({'telemetry_invite_sample_rate': rate});
    await _remoteConfig.fetchAndActivate();
  }

  Future<void> setDriverSafetyEnabled(bool enabled) async {
    await _remoteConfig.setDefaults({'driver_safety_enabled': enabled});
    await _remoteConfig.fetchAndActivate();
  }

  // Emergency Response flags
  bool get emergencyResponseEnabled => _remoteConfig.getBool('emergency_response_enabled');
  bool get wanderingPredictionEnabled => _remoteConfig.getBool('wandering_prediction_enabled');

  Future<void> setEmergencyResponseEnabled(bool enabled) async {
    await _remoteConfig.setDefaults({'emergency_response_enabled': enabled});
    await _remoteConfig.fetchAndActivate();
  }

  Future<void> setWanderingPredictionEnabled(bool enabled) async {
    await _remoteConfig.setDefaults({'wandering_prediction_enabled': enabled});
    await _remoteConfig.fetchAndActivate();
  }
}
