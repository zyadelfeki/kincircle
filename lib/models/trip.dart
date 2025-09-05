import 'package:cloud_firestore/cloud_firestore.dart';

class Trip {
  Trip({
    required this.id,
    required this.userId,
    required this.familyId,
    required this.startTime,
    required this.endTime,
    required this.durationMinutes,
    required this.distanceKm,
    required this.startAddress,
    required this.endAddress,
    required this.routePath,
  });

  /// Factory constructor to create Trip from Firestore data
  factory Trip.fromMap(String id, Map<String, dynamic> data) {
    return Trip(
      id: id,
      userId: data['userId'] ?? '',
      familyId: data['familyId'] ?? '',
      startTime: (data['startTime'] as Timestamp).toDate(),
      endTime: (data['endTime'] as Timestamp).toDate(),
      durationMinutes: (data['durationMinutes'] ?? 0).toDouble(),
      distanceKm: (data['distanceKm'] ?? 0).toDouble(),
      startAddress: data['startAddress'] ?? '',
      endAddress: data['endAddress'] ?? '',
      routePath: List<GeoPoint>.from(data['routePath'] ?? []),
    );
  }

  final String id;
  final String userId;
  final String familyId;
  final DateTime startTime;
  final DateTime endTime;
  final double durationMinutes;
  final double distanceKm;
  final String startAddress;
  final String endAddress;
  final List<GeoPoint> routePath;

  /// Convert Trip to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'familyId': familyId,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'durationMinutes': durationMinutes,
      'distanceKm': distanceKm,
      'startAddress': startAddress,
      'endAddress': endAddress,
      'routePath': routePath,
    };
  }

  /// Get formatted duration string
  String get formattedDuration {
    final hours = (durationMinutes / 60).floor();
    final minutes = (durationMinutes % 60).round();
    
    if (hours > 0) {
  return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  /// Get formatted distance string
  String get formattedDistance {
    if (distanceKm < 1) {
  return '${(distanceKm * 1000).round()}m';
    } else {
      return '${distanceKm.toStringAsFixed(1)}km';
    }
  }

  /// Get formatted start time
  String get formattedStartTime {
    final now = DateTime.now();
    final difference = now.difference(startTime);
    
    if (difference.inDays == 0) {
      return 'Today ${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Yesterday ${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays < 7) {
      return '${_getDayName(startTime.weekday)} ${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';
    } else {
      return '${startTime.day}/${startTime.month}/${startTime.year}';
    }
  }

  /// Get formatted date
  String get formattedDate {
    final now = DateTime.now();
    final difference = now.difference(startTime);
    
    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return _getDayName(startTime.weekday);
    } else {
      return '${startTime.day}/${startTime.month}/${startTime.year}';
    }
  }

  String _getDayName(int weekday) {
    switch (weekday) {
      case 1: return 'Monday';
      case 2: return 'Tuesday';
      case 3: return 'Wednesday';
      case 4: return 'Thursday';
      case 5: return 'Friday';
      case 6: return 'Saturday';
      case 7: return 'Sunday';
      default: return '';
    }
  }

  /// Create a copy of this Trip with some fields replaced
  Trip copyWith({
    String? id,
    String? userId,
    String? familyId,
    DateTime? startTime,
    DateTime? endTime,
    double? durationMinutes,
    double? distanceKm,
    String? startAddress,
    String? endAddress,
    List<GeoPoint>? routePath,
  }) {
    return Trip(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      familyId: familyId ?? this.familyId,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      distanceKm: distanceKm ?? this.distanceKm,
      startAddress: startAddress ?? this.startAddress,
      endAddress: endAddress ?? this.endAddress,
      routePath: routePath ?? this.routePath,
    );
  }
}
