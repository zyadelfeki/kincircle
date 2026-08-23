import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:kincircle/services/location_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocationService service;

  setUp(() {
    service = LocationService();
    service.resetThrottleStateForTesting();
  });

  Position createPosition({
    required double latitude,
    required double longitude,
    DateTime? timestamp,
  }) {
    return Position(
      latitude: latitude,
      longitude: longitude,
      timestamp: timestamp ?? DateTime.now(),
      accuracy: 5.0,
      altitude: 0.0,
      altitudeAccuracy: 0.0,
      heading: 0.0,
      headingAccuracy: 0.0,
      speed: 0.0,
      speedAccuracy: 0.0,
    );
  }

  group('LocationService Write Throttle Tests', () {
    test('a) Two positions 5s and 20m apart -> only first writes, second throttled', () {
      final baseTime = DateTime(2026, 1, 1, 12, 0, 0);
      final p1 = createPosition(latitude: 40.712800, longitude: -74.006000, timestamp: baseTime);

      // Initial position when no previous write exists should write
      expect(service.shouldWriteLocation(p1, now: baseTime), isTrue);

      // Simulate writing p1
      service.recordWrittenPositionForTesting(p1, baseTime);

      // Position 2: 5 seconds later, ~20 meters away
      // At latitude 40.7128, 0.00018 degrees lat is ~20 meters
      final p2Time = baseTime.add(const Duration(seconds: 5));
      final p2 = createPosition(latitude: 40.712980, longitude: -74.006000, timestamp: p2Time);

      final distance = Geolocator.distanceBetween(
        p1.latitude,
        p1.longitude,
        p2.latitude,
        p2.longitude,
      );
      expect(distance, lessThan(100.0));
      expect(distance, greaterThan(15.0));

      // Second position should be throttled (returns false)
      expect(service.shouldWriteLocation(p2, now: p2Time), isFalse);
    });

    test('b) A position 6 minutes after the last write (stationary) -> writes (heartbeat)', () {
      final baseTime = DateTime(2026, 1, 1, 12, 0, 0);
      final p1 = createPosition(latitude: 40.712800, longitude: -74.006000, timestamp: baseTime);

      // Record first write
      service.recordWrittenPositionForTesting(p1, baseTime);

      // Position 2: 6 minutes later, same location (0m distance)
      final p2Time = baseTime.add(const Duration(minutes: 6));
      final p2 = createPosition(latitude: 40.712800, longitude: -74.006000, timestamp: p2Time);

      // Heartbeat triggers write even if stationary
      expect(service.shouldWriteLocation(p2, now: p2Time), isTrue);
    });

    test('c) A position 600 meters away 10 seconds later (driving fast) -> writes (distance override)', () {
      final baseTime = DateTime(2026, 1, 1, 12, 0, 0);
      final p1 = createPosition(latitude: 40.712800, longitude: -74.006000, timestamp: baseTime);

      // Record first write
      service.recordWrittenPositionForTesting(p1, baseTime);

      // Position 2: 10 seconds later, ~600m away
      // At latitude 40.7128, 0.0054 degrees lat is ~600 meters
      final p2Time = baseTime.add(const Duration(seconds: 10));
      final p2 = createPosition(latitude: 40.718200, longitude: -74.006000, timestamp: p2Time);

      final distance = Geolocator.distanceBetween(
        p1.latitude,
        p1.longitude,
        p2.latitude,
        p2.longitude,
      );
      expect(distance, greaterThanOrEqualTo(500.0));

      // Significant distance triggers write override even within minWriteInterval
      expect(service.shouldWriteLocation(p2, now: p2Time), isTrue);
    });
  });
}
