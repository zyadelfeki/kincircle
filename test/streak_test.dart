import 'package:flutter_test/flutter_test.dart';
import 'package:kincircle/models/user_model.dart';
import 'package:kincircle/services/streak_service.dart';

void main() {
  group('StreakService Unit & Date Algorithm Tests', () {
    final referenceDate = DateTime(2026, 8, 30, 14, 0, 0);

    test('Empty check-ins list returns 0 streak and false checkedInToday', () {
      final streak = StreakService.calculateStreak(
        localDates: [],
        referenceNow: referenceDate,
      );

      expect(streak.currentStreak, 0);
      expect(streak.longestStreak, 0);
      expect(streak.checkedInToday, false);
      expect(streak.lastCheckInDate, isNull);
    });

    test('Consecutive days ending today calculates correct current and longest streak', () {
      final dates = [
        '2026-08-30', // today
        '2026-08-29',
        '2026-08-28',
        '2026-08-27',
        '2026-08-26',
      ];

      final streak = StreakService.calculateStreak(
        localDates: dates,
        referenceNow: referenceDate,
      );

      expect(streak.currentStreak, 5);
      expect(streak.longestStreak, 5);
      expect(streak.checkedInToday, true);
      expect(streak.lastCheckInDate, '2026-08-30');
    });

    test('Consecutive days ending yesterday preserves active streak awaiting today check-in', () {
      final dates = [
        '2026-08-29', // yesterday
        '2026-08-28',
        '2026-08-27',
        '2026-08-26',
      ];

      final streak = StreakService.calculateStreak(
        localDates: dates,
        referenceNow: referenceDate,
      );

      expect(streak.currentStreak, 4);
      expect(streak.longestStreak, 4);
      expect(streak.checkedInToday, false);
      expect(streak.lastCheckInDate, '2026-08-29');
    });

    test('Gap day break: missing both yesterday and today resets current streak to 0', () {
      final dates = [
        '2026-08-28', // 2 days ago
        '2026-08-27',
        '2026-08-26',
      ];

      final streak = StreakService.calculateStreak(
        localDates: dates,
        referenceNow: referenceDate,
      );

      expect(streak.currentStreak, 0);
      expect(streak.longestStreak, 3);
      expect(streak.checkedInToday, false);
    });

    test('Check-in today after missing yesterday starts streak at 1', () {
      final dates = [
        '2026-08-30', // today
        // missing 2026-08-29 (yesterday)
        '2026-08-28',
        '2026-08-27',
      ];

      final streak = StreakService.calculateStreak(
        localDates: dates,
        referenceNow: referenceDate,
      );

      expect(streak.currentStreak, 1);
      expect(streak.longestStreak, 2); // 28 & 27 was run of 2
      expect(streak.checkedInToday, true);
    });

    test('Tracks historical longest streak higher than current streak', () {
      final dates = [
        // 7 consecutive days in July
        '2026-07-10',
        '2026-07-11',
        '2026-07-12',
        '2026-07-13',
        '2026-07-14',
        '2026-07-15',
        '2026-07-16',
        // Current 2-day run in August
        '2026-08-29',
        '2026-08-30',
      ];

      final streak = StreakService.calculateStreak(
        localDates: dates,
        referenceNow: referenceDate,
      );

      expect(streak.currentStreak, 2);
      expect(streak.longestStreak, 7);
      expect(streak.checkedInToday, true);
    });

    test('Duplicate entries for the same day are deduplicated seamlessly', () {
      final dates = [
        '2026-08-30',
        '2026-08-30',
        '2026-08-29',
        '2026-08-29',
        '2026-08-28',
      ];

      final streak = StreakService.calculateStreak(
        localDates: dates,
        referenceNow: referenceDate,
      );

      expect(streak.currentStreak, 3);
      expect(streak.longestStreak, 3);
    });

    test('Date formatting and parsing round-trips correctly', () {
      final date = DateTime(2026, 8, 30);
      final formatted = StreakService.formatDate(date);
      expect(formatted, '2026-08-30');

      final parsed = StreakService.parseLocalDate(formatted);
      expect(parsed.year, 2026);
      expect(parsed.month, 8);
      expect(parsed.day, 30);
    });

    test('Leaderboard sorting sorts by currentStreak descending, tie-breaks by longestStreak', () {
      final userAlice = AppUser(
        uid: 'user_alice',
        displayName: 'Alice',
        photoURL: '',
        isInvisible: false,
      );
      final userBob = AppUser(
        uid: 'user_bob',
        displayName: 'Bob',
        photoURL: '',
        isInvisible: false,
      );
      final userCharlie = AppUser(
        uid: 'user_charlie',
        displayName: 'Charlie',
        photoURL: '',
        isInvisible: false,
      );
      final userDave = AppUser(
        uid: 'user_dave',
        displayName: 'Dave',
        photoURL: '',
        isInvisible: false,
      );

      final entries = [
        LeaderboardEntry(
          member: userCharlie,
          currentStreak: 2,
          longestStreak: 15,
          checkedInToday: true,
        ),
        LeaderboardEntry(
          member: userBob,
          currentStreak: 5,
          longestStreak: 5,
          checkedInToday: true,
        ),
        LeaderboardEntry(
          member: userAlice,
          currentStreak: 5,
          longestStreak: 10,
          checkedInToday: true,
        ),
        LeaderboardEntry(
          member: userDave,
          currentStreak: 0,
          longestStreak: 1,
          checkedInToday: false,
        ),
      ];

      entries.sort((a, b) {
        final int cmpCurrent = b.currentStreak.compareTo(a.currentStreak);
        if (cmpCurrent != 0) return cmpCurrent;
        final int cmpLongest = b.longestStreak.compareTo(a.longestStreak);
        if (cmpLongest != 0) return cmpLongest;
        return a.member.displayName.compareTo(b.member.displayName);
      });

      expect(entries[0].member.displayName, 'Alice'); // Current: 5, Longest: 10
      expect(entries[1].member.displayName, 'Bob');   // Current: 5, Longest: 5
      expect(entries[2].member.displayName, 'Charlie'); // Current: 2, Longest: 15
      expect(entries[3].member.displayName, 'Dave');  // Current: 0, Longest: 1
    });
  });
}
