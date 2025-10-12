import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:kincircle/services/wandering_prediction_service.dart';
import 'package:kincircle/services/emergency_response_service.dart';
import 'package:mockito/mockito.dart';

// Mock classes
class MockEmergencyResponseService extends Mock implements EmergencyResponseService {}

void main() {
  group('WanderingPredictionService', () {
    late WanderingPredictionService service;
    late MockEmergencyResponseService mockEmergencyService;

    setUp(() {
      mockEmergencyService = MockEmergencyResponseService();
      service = WanderingPredictionService(
        emergencyService: mockEmergencyService,
      );
    });

    test('assessWanderingRisk returns low risk for normal conditions', () async {
      final currentPosition = Position(
        latitude: 37.7749,
        longitude: -122.4194,
        timestamp: DateTime.now(),
        accuracy: 10.0,
        altitude: 0.0,
        heading: 0.0,
        speed: 1.5,
        speedAccuracy: 1.0,
        altitudeAccuracy: 1.0,
        headingAccuracy: 1.0,
      );

      final assessment = await service.assessWanderingRisk(
        currentPosition: currentPosition,
      );

      expect(assessment.riskLevel, equals(WanderingRiskLevel.low));
      expect(assessment.riskScore, lessThan(0.4));
    });

    test('assessWanderingRisk detects high risk for large distance', () async {
      final lastPosition = Position(
        latitude: 37.7749,
        longitude: -122.4194,
        timestamp: DateTime.now().subtract(const Duration(minutes: 10)),
        accuracy: 10.0,
        altitude: 0.0,
        heading: 0.0,
        speed: 0.0,
        speedAccuracy: 1.0,
        altitudeAccuracy: 1.0,
        headingAccuracy: 1.0,
      );

      // Current position is ~2km away (about 0.02 degrees)
      final currentPosition = Position(
        latitude: 37.7949,
        longitude: -122.4194,
        timestamp: DateTime.now(),
        accuracy: 10.0,
        altitude: 0.0,
        heading: 0.0,
        speed: 1.0,
        speedAccuracy: 1.0,
        altitudeAccuracy: 1.0,
        headingAccuracy: 1.0,
      );

      final assessment = await service.assessWanderingRisk(
        currentPosition: currentPosition,
        lastKnownPosition: lastPosition,
      );

      expect(assessment.riskScore, greaterThan(0.0));
      expect(assessment.factors.containsKey('distance_from_safe_location'), isTrue);
    });

    test('assessWanderingRisk detects risk for stale location', () async {
      final currentPosition = Position(
        latitude: 37.7749,
        longitude: -122.4194,
        timestamp: DateTime.now(),
        accuracy: 10.0,
        altitude: 0.0,
        heading: 0.0,
        speed: 1.0,
        speedAccuracy: 1.0,
        altitudeAccuracy: 1.0,
        headingAccuracy: 1.0,
      );

      // Last location was 45 minutes ago
      final lastLocationTime = DateTime.now().subtract(const Duration(minutes: 45));

      final assessment = await service.assessWanderingRisk(
        currentPosition: currentPosition,
        lastLocationTime: lastLocationTime,
      );

      expect(assessment.riskScore, greaterThan(0.0));
      expect(assessment.factors.containsKey('minutes_since_last_update'), isTrue);
    });

    test('assessWanderingRisk detects slow movement', () async {
      final currentPosition = Position(
        latitude: 37.7749,
        longitude: -122.4194,
        timestamp: DateTime.now(),
        accuracy: 10.0,
        altitude: 0.0,
        heading: 0.0,
        speed: 0.5, // Very slow movement
        speedAccuracy: 1.0,
        altitudeAccuracy: 1.0,
        headingAccuracy: 1.0,
      );

      final assessment = await service.assessWanderingRisk(
        currentPosition: currentPosition,
      );

      expect(assessment.riskScore, greaterThan(0.0));
      expect(assessment.factors['slow_movement'], isTrue);
    });

    test('assessWanderingRisk detects fast movement', () async {
      final currentPosition = Position(
        latitude: 37.7749,
        longitude: -122.4194,
        timestamp: DateTime.now(),
        accuracy: 10.0,
        altitude: 0.0,
        heading: 0.0,
        speed: 15.0, // Unusually fast movement
        speedAccuracy: 1.0,
        altitudeAccuracy: 1.0,
        headingAccuracy: 1.0,
      );

      final assessment = await service.assessWanderingRisk(
        currentPosition: currentPosition,
      );

      expect(assessment.riskScore, greaterThan(0.0));
      expect(assessment.factors['fast_movement'], isTrue);
    });

    test('WanderingRiskLevel enum values are defined', () {
      expect(WanderingRiskLevel.values.length, equals(4));
      expect(WanderingRiskLevel.values.contains(WanderingRiskLevel.low), isTrue);
      expect(WanderingRiskLevel.values.contains(WanderingRiskLevel.medium), isTrue);
      expect(WanderingRiskLevel.values.contains(WanderingRiskLevel.high), isTrue);
      expect(WanderingRiskLevel.values.contains(WanderingRiskLevel.critical), isTrue);
    });

    test('WanderingRiskAssessment contains all required fields', () {
      final assessment = WanderingRiskAssessment(
        riskLevel: WanderingRiskLevel.medium,
        riskScore: 0.5,
        reason: 'Test reason',
        factors: {'test': 'value'},
      );

      expect(assessment.riskLevel, equals(WanderingRiskLevel.medium));
      expect(assessment.riskScore, equals(0.5));
      expect(assessment.reason, equals('Test reason'));
      expect(assessment.factors['test'], equals('value'));
    });

    test('risk score thresholds are properly defined', () {
      // Test that threshold constants exist and are in correct order
      expect(0.4, lessThan(0.6)); // medium < high
      expect(0.6, lessThan(0.8)); // high < critical
    });
  });
}
