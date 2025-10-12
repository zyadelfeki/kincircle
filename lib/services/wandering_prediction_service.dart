import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'emergency_response_service.dart';

/// Wandering risk level based on location patterns
enum WanderingRiskLevel {
  low,
  medium,
  high,
  critical,
}

/// Result of wandering risk assessment
class WanderingRiskAssessment {
  final WanderingRiskLevel riskLevel;
  final double riskScore;
  final String reason;
  final Map<String, dynamic> factors;

  WanderingRiskAssessment({
    required this.riskLevel,
    required this.riskScore,
    required this.reason,
    required this.factors,
  });
}

/// Service for predicting and responding to wandering behavior
class WanderingPredictionService {
  final EmergencyResponseService _emergencyService;
  
  // Thresholds for risk levels
  static const double _mediumRiskThreshold = 0.4;
  static const double _highRiskThreshold = 0.6;
  static const double _criticalRiskThreshold = 0.8;

  WanderingPredictionService({
    EmergencyResponseService? emergencyService,
  }) : _emergencyService = emergencyService ?? EmergencyResponseService();

  /// Assess wandering risk based on location data
  Future<WanderingRiskAssessment> assessWanderingRisk({
    required Position currentPosition,
    Position? lastKnownPosition,
    DateTime? lastLocationTime,
    List<Position>? recentPositions,
  }) async {
    double riskScore = 0.0;
    final factors = <String, dynamic>{};

    // Factor 1: Distance from last known safe location
    if (lastKnownPosition != null) {
      final distanceMeters = Geolocator.distanceBetween(
        lastKnownPosition.latitude,
        lastKnownPosition.longitude,
        currentPosition.latitude,
        currentPosition.longitude,
      );
      
      // Risk increases with distance (>1km is concerning)
      if (distanceMeters > 1000) {
        riskScore += 0.3;
        factors['distance_from_safe_location'] = distanceMeters;
      }
    }

    // Factor 2: Time since last location update
    if (lastLocationTime != null) {
      final timeSinceUpdate = DateTime.now().difference(lastLocationTime);
      
      // Risk increases if location updates are infrequent
      if (timeSinceUpdate.inMinutes > 30) {
        riskScore += 0.2;
        factors['minutes_since_last_update'] = timeSinceUpdate.inMinutes;
      }
    }

    // Factor 3: Movement pattern analysis
    if (recentPositions != null && recentPositions.length >= 3) {
      final movementVariance = _calculateMovementVariance(recentPositions);
      
      // High variance might indicate wandering/confusion
      if (movementVariance > 0.5) {
        riskScore += 0.3;
        factors['movement_variance'] = movementVariance;
      }
    }

    // Factor 4: Speed analysis
    final speed = currentPosition.speed;
    if (speed > 0 && speed < 1.0) {
      // Very slow movement might indicate disorientation
      riskScore += 0.1;
      factors['slow_movement'] = true;
    } else if (speed > 10.0) {
      // Unusually fast movement is concerning
      riskScore += 0.2;
      factors['fast_movement'] = true;
    }

    // Determine risk level
    final riskLevel = _determineRiskLevel(riskScore);
    final reason = _generateRiskReason(riskLevel, factors);

    return WanderingRiskAssessment(
      riskLevel: riskLevel,
      riskScore: riskScore,
      reason: reason,
      factors: factors,
    );
  }

  /// Monitor location and trigger emergency responses when needed
  Future<void> monitorAndRespond({
    required Position currentPosition,
    Position? lastKnownPosition,
    DateTime? lastLocationTime,
    List<Position>? recentPositions,
  }) async {
    final assessment = await assessWanderingRisk(
      currentPosition: currentPosition,
      lastKnownPosition: lastKnownPosition,
      lastLocationTime: lastLocationTime,
      recentPositions: recentPositions,
    );

    debugPrint('Wandering risk assessment: ${assessment.riskLevel.name} (score: ${assessment.riskScore})');

    // Trigger emergency response based on risk level
    if (assessment.riskLevel == WanderingRiskLevel.medium) {
      await _emergencyService.triggerEmergencyResponse(
        riskLevel: EmergencyRiskLevel.medium,
        reason: assessment.reason,
        metadata: {
          'type': 'wandering_detected',
          'risk_score': assessment.riskScore,
          'factors': assessment.factors,
          'location': {
            'latitude': currentPosition.latitude,
            'longitude': currentPosition.longitude,
          },
        },
      );
    } else if (assessment.riskLevel == WanderingRiskLevel.high) {
      await _emergencyService.triggerEmergencyResponse(
        riskLevel: EmergencyRiskLevel.high,
        reason: assessment.reason,
        metadata: {
          'type': 'wandering_detected',
          'risk_score': assessment.riskScore,
          'factors': assessment.factors,
          'location': {
            'latitude': currentPosition.latitude,
            'longitude': currentPosition.longitude,
          },
        },
      );
    } else if (assessment.riskLevel == WanderingRiskLevel.critical) {
      await _emergencyService.triggerEmergencyResponse(
        riskLevel: EmergencyRiskLevel.critical,
        reason: assessment.reason,
        metadata: {
          'type': 'wandering_detected',
          'risk_score': assessment.riskScore,
          'factors': assessment.factors,
          'location': {
            'latitude': currentPosition.latitude,
            'longitude': currentPosition.longitude,
          },
        },
      );
    }
  }

  /// Calculate variance in movement patterns
  double _calculateMovementVariance(List<Position> positions) {
    if (positions.length < 2) return 0.0;

    final distances = <double>[];
    for (int i = 0; i < positions.length - 1; i++) {
      final distance = Geolocator.distanceBetween(
        positions[i].latitude,
        positions[i].longitude,
        positions[i + 1].latitude,
        positions[i + 1].longitude,
      );
      distances.add(distance);
    }

    // Calculate mean
    final mean = distances.reduce((a, b) => a + b) / distances.length;

    // Calculate variance
    final variance = distances
        .map((d) => (d - mean) * (d - mean))
        .reduce((a, b) => a + b) / distances.length;

    // Normalize variance (0-1 scale)
    return (variance / 10000).clamp(0.0, 1.0);
  }

  /// Determine risk level from risk score
  WanderingRiskLevel _determineRiskLevel(double riskScore) {
    if (riskScore >= _criticalRiskThreshold) {
      return WanderingRiskLevel.critical;
    } else if (riskScore >= _highRiskThreshold) {
      return WanderingRiskLevel.high;
    } else if (riskScore >= _mediumRiskThreshold) {
      return WanderingRiskLevel.medium;
    } else {
      return WanderingRiskLevel.low;
    }
  }

  /// Generate human-readable reason for risk level
  String _generateRiskReason(
    WanderingRiskLevel riskLevel,
    Map<String, dynamic> factors,
  ) {
    final reasons = <String>[];

    if (factors.containsKey('distance_from_safe_location')) {
      final distance = factors['distance_from_safe_location'] as double;
      reasons.add('${(distance / 1000).toStringAsFixed(1)}km from safe location');
    }

    if (factors.containsKey('minutes_since_last_update')) {
      final minutes = factors['minutes_since_last_update'] as int;
      reasons.add('$minutes minutes since last update');
    }

    if (factors['movement_variance'] != null) {
      reasons.add('Erratic movement pattern detected');
    }

    if (factors['slow_movement'] == true) {
      reasons.add('Unusually slow movement');
    }

    if (factors['fast_movement'] == true) {
      reasons.add('Unusually fast movement');
    }

    if (reasons.isEmpty) {
      return 'Wandering behavior detected';
    }

    return reasons.join('; ');
  }
}
