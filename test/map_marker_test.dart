import 'package:flutter_test/flutter_test.dart';
import 'package:kincircle/design/kincircle_screen_tokens.dart';
import 'package:kincircle/models/user_model.dart';
import 'package:kincircle/screens/map_screen.dart';

void main() {
  group('Map Marker Unit Tests', () {
    const palette = KinCirclePaletteData.dark;
    final now = DateTime(2026, 8, 30, 15, 0, 0);

    test('1. statusColorFor: stale -> gray, sos -> red, fresh -> green, self -> accent', () {
      // Stale member (> 3 hours old or null lastUpdated)
      final staleMember = AppUser(
        uid: 'user-stale',
        displayName: 'Stale User',
        lastUpdated: now.subtract(const Duration(hours: 4)),
      );
      expect(
        statusColorFor(staleMember, now, palette: palette),
        equals(palette.textMuted),
        reason: 'Older than 3 hours should be gray (textMuted)',
      );

      final nullUpdatedMember = AppUser(
        uid: 'user-null',
        displayName: 'Null User',
        lastUpdated: null,
      );
      expect(
        statusColorFor(nullUpdatedMember, now, palette: palette),
        equals(palette.textMuted),
        reason: 'Null lastUpdated should be gray (textMuted)',
      );

      // Active SOS / needsHelp
      final sosMember = AppUser(
        uid: 'user-sos',
        displayName: 'SOS User',
        needsHelp: true,
        lastUpdated: now.subtract(const Duration(minutes: 5)),
      );
      expect(
        statusColorFor(sosMember, now, palette: palette),
        equals(palette.error),
        reason: 'Active SOS should be red (error)',
      );

      final activeSosFlagMember = AppUser(
        uid: 'user-sos-flag',
        displayName: 'SOS Flag User',
        needsHelp: false,
        lastUpdated: now.subtract(const Duration(minutes: 5)),
      );
      expect(
        statusColorFor(
          activeSosFlagMember,
          now,
          hasActiveSos: true,
          palette: palette,
        ),
        equals(palette.error),
        reason: 'Active SOS flag should be red (error)',
      );

      // Fresh member (< 3 hours old)
      final freshMember = AppUser(
        uid: 'user-fresh',
        displayName: 'Fresh User',
        lastUpdated: now.subtract(const Duration(minutes: 10)),
      );
      expect(
        statusColorFor(freshMember, now, palette: palette),
        equals(palette.success),
        reason: 'Fresh member should be green (success)',
      );

      // Current user
      expect(
        statusColorFor(
          freshMember,
          now,
          isCurrentUser: true,
          palette: palette,
        ),
        equals(palette.accent),
        reason: 'Current user gets accent ring',
      );
    });

    test('2. batteryBucket: 100->10, 55->5, 21->2, 20->2, 19->1, null->null bucket', () {
      expect(batteryBucket(100), equals(10));
      expect(batteryBucket(55), equals(5));
      expect(batteryBucket(21), equals(2));
      expect(batteryBucket(20), equals(2));
      expect(batteryBucket(19), equals(1));
      expect(batteryBucket(null), isNull);
    });

    test('Cache key identical when battery moves within bucket (100->95) and different across (55->45)', () {
      final key100 = markerCacheKey(
        uid: 'user-1',
        displayName: 'John Doe',
        statusColor: palette.success,
        batteryLevel: 100,
      );
      final key95 = markerCacheKey(
        uid: 'user-1',
        displayName: 'John Doe',
        statusColor: palette.success,
        batteryLevel: 95,
      );
      expect(key100, equals(key95), reason: '100 and 95 should yield identical cache keys');

      final key55 = markerCacheKey(
        uid: 'user-1',
        displayName: 'John Doe',
        statusColor: palette.success,
        batteryLevel: 55,
      );
      final key45 = markerCacheKey(
        uid: 'user-1',
        displayName: 'John Doe',
        statusColor: palette.success,
        batteryLevel: 45,
      );
      expect(key55, isNot(equals(key45)), reason: '55 and 45 should yield different cache keys');
    });

    test('initialsFor: first letters of first+last name parts uppercased', () {
      expect(initialsFor('John Doe'), equals('JD'));
      expect(initialsFor('alice'), equals('A'));
      expect(initialsFor('Mary Jane Watson'), equals('MW'));
      expect(initialsFor('  Bob   Smith  '), equals('BS'));
      expect(initialsFor(''), equals('U'));
    });

    test('batteryColorFor: green above 50, orange 20-50, red below 20', () {
      expect(batteryColorFor(80, palette: palette), equals(palette.success));
      expect(batteryColorFor(51, palette: palette), equals(palette.success));
      expect(batteryColorFor(50, palette: palette), equals(palette.warning));
      expect(batteryColorFor(20, palette: palette), equals(palette.warning));
      expect(batteryColorFor(19, palette: palette), equals(palette.error));
      expect(batteryColorFor(5, palette: palette), equals(palette.error));
    });
  });
}
