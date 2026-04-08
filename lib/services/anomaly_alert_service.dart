import 'dart:math' as math;

class AnomalyAlert {
  final String uid;
  final String displayName;
  final double lat;
  final double lng;
  final DateTime detectedAt;

  const AnomalyAlert({
    required this.uid,
    required this.displayName,
    required this.lat,
    required this.lng,
    required this.detectedAt,
  });
}

class AnomalyAlertService {
  static List<AnomalyAlert> checkForAnomalies(
    String circleId,
    List<Map<String, dynamic>> memberLocations,
  ) {
    if (circleId.isEmpty || memberLocations.isEmpty) {
      return const <AnomalyAlert>[];
    }

    final DateTime now = DateTime.now();
    if (!_isActiveHour(now)) {
      return const <AnomalyAlert>[];
    }

    final Map<String, List<Map<String, dynamic>>> byUid =
        <String, List<Map<String, dynamic>>>{};

    for (final Map<String, dynamic> point in memberLocations) {
      final String uid = (point['uid'] as String?)?.trim() ?? '';
      if (uid.isEmpty) continue;
      byUid.putIfAbsent(uid, () => <Map<String, dynamic>>[]).add(point);
    }

    final List<AnomalyAlert> anomalies = <AnomalyAlert>[];

    for (final MapEntry<String, List<Map<String, dynamic>>> entry
        in byUid.entries) {
      final List<Map<String, dynamic>> points = entry.value;
      if (points.length < 2) continue;

      points.sort(
        (Map<String, dynamic> a, Map<String, dynamic> b) =>
            _asDateTime(a['timestamp']).compareTo(_asDateTime(b['timestamp'])),
      );

      final Map<String, dynamic> current = points.last;
      final DateTime currentTs = _asDateTime(current['timestamp']);
      final DateTime targetTs = currentTs.subtract(const Duration(minutes: 15));

      Map<String, dynamic>? previous;
      for (final Map<String, dynamic> point in points) {
        final DateTime ts = _asDateTime(point['timestamp']);
        if (ts.isAfter(targetTs)) break;
        previous = point;
      }

      if (previous == null) continue;

      final double previousLat = _asDouble(previous['lat']);
      final double previousLng = _asDouble(previous['lng']);
      final double currentLat = _asDouble(current['lat']);
      final double currentLng = _asDouble(current['lng']);
      final double speedKmh = _asDouble(current['speed']);

      final double distanceMeters = _haversineMeters(
        previousLat,
        previousLng,
        currentLat,
        currentLng,
      );

      if (distanceMeters < 50 && speedKmh < 5) {
        anomalies.add(
          AnomalyAlert(
            uid: entry.key,
            displayName: (current['displayName'] as String?) ?? entry.key,
            lat: currentLat,
            lng: currentLng,
            detectedAt: now,
          ),
        );
      }
    }

    return anomalies;
  }

  static bool _isActiveHour(DateTime now) {
    return now.hour >= 6 && now.hour < 22;
  }

  static DateTime _asDateTime(dynamic value) {
    if (value is DateTime) return value;
    if (value is String) {
      final DateTime? parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed;
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  static double _asDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    return 0;
  }

  static double _haversineMeters(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const double earthRadiusMeters = 6371000;

    final double dLat = _toRadians(lat2 - lat1);
    final double dLng = _toRadians(lng2 - lng1);

    final double a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
            math.cos(_toRadians(lat1)) *
                math.cos(_toRadians(lat2)) *
                math.sin(dLng / 2) *
                math.sin(dLng / 2);

    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusMeters * c;
  }

  static double _toRadians(double degrees) {
    return degrees * (math.pi / 180.0);
  }
}
