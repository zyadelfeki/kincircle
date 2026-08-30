import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_model.dart';

/// User streak state
class UserStreak {
  final int currentStreak;
  final int longestStreak;
  final String? lastCheckInDate;
  final bool checkedInToday;

  const UserStreak({
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.lastCheckInDate,
    this.checkedInToday = false,
  });

  @override
  String toString() =>
      'UserStreak(current: $currentStreak, longest: $longestStreak, checkedInToday: $checkedInToday)';
}

/// Leaderboard item for a circle member
class LeaderboardEntry {
  final AppUser member;
  final int currentStreak;
  final int longestStreak;
  final bool checkedInToday;

  const LeaderboardEntry({
    required this.member,
    required this.currentStreak,
    required this.longestStreak,
    required this.checkedInToday,
  });
}

/// Service managing family daily check-ins and streaks
class StreakService {
  StreakService._internal({
    FirebaseFirestore? firestore,
    DateTime Function()? nowProvider,
  })  : _firestoreInstance = firestore,
        _nowProvider = nowProvider;

  factory StreakService({
    FirebaseFirestore? firestore,
    DateTime Function()? nowProvider,
  }) {
    if (firestore != null || nowProvider != null) {
      return StreakService._internal(
        firestore: firestore,
        nowProvider: nowProvider,
      );
    }
    return _instance;
  }

  static final StreakService _instance = StreakService._internal();
  static StreakService get instance => _instance;

  FirebaseFirestore? _firestoreInstance;
  final DateTime Function()? _nowProvider;

  FirebaseFirestore get _firestore =>
      _firestoreInstance ??= FirebaseFirestore.instance;

  DateTime get now => _nowProvider != null ? _nowProvider!() : DateTime.now();

  static const List<int> streakMilestones = <int>[7, 30, 100, 365];

  /// Formats date to 'yyyy-MM-dd'
  static String formatDate(DateTime dt) {
    final String y = dt.year.toString().padLeft(4, '0');
    final String m = dt.month.toString().padLeft(2, '0');
    final String d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Parses 'yyyy-MM-dd' to DateTime normalized to midnight UTC
  static DateTime parseLocalDate(String dateStr) {
    final List<String> parts = dateStr.split('-');
    if (parts.length != 3) {
      return DateTime(2000, 1, 1);
    }
    final int y = int.tryParse(parts[0]) ?? 2000;
    final int m = int.tryParse(parts[1]) ?? 1;
    final int d = int.tryParse(parts[2]) ?? 1;
    return DateTime(y, m, d);
  }

  /// Calculates streak data from a list of 'yyyy-MM-dd' strings against reference date [referenceNow].
  static UserStreak calculateStreak({
    required List<String> localDates,
    required DateTime referenceNow,
  }) {
    if (localDates.isEmpty) {
      return const UserStreak();
    }

    final Set<String> uniqueDateStrings = localDates.toSet();
    final Set<DateTime> dateSet = <DateTime>{};
    for (final String s in uniqueDateStrings) {
      dateSet.add(parseLocalDate(s));
    }

    final DateTime today = DateTime(
      referenceNow.year,
      referenceNow.month,
      referenceNow.day,
    );
    final DateTime yesterday = DateTime(
      referenceNow.year,
      referenceNow.month,
      referenceNow.day - 1,
    );

    final bool checkedInToday = dateSet.contains(today);

    // Calculate current streak
    int current = 0;
    if (checkedInToday) {
      current = 1;
      while (dateSet.contains(DateTime(today.year, today.month, today.day - current))) {
        current++;
      }
    } else if (dateSet.contains(yesterday)) {
      current = 1;
      while (dateSet.contains(DateTime(yesterday.year, yesterday.month, yesterday.day - current))) {
        current++;
      }
    }

    // Calculate longest streak across history
    final List<DateTime> sortedAsc = dateSet.toList()
      ..sort((a, b) => a.compareTo(b));

    int longest = sortedAsc.isNotEmpty ? 1 : 0;
    int currentRun = 1;

    for (int i = 1; i < sortedAsc.length; i++) {
      final DateTime prev = sortedAsc[i - 1];
      final DateTime curr = sortedAsc[i];
      final DateTime expectedNext = DateTime(prev.year, prev.month, prev.day + 1);

      if (curr.year == expectedNext.year &&
          curr.month == expectedNext.month &&
          curr.day == expectedNext.day) {
        currentRun++;
        if (currentRun > longest) {
          longest = currentRun;
        }
      } else if (curr.isAfter(prev)) {
        currentRun = 1;
      }
    }

    if (current > longest) {
      longest = current;
    }

    String? latestDateStr;
    if (sortedAsc.isNotEmpty) {
      latestDateStr = formatDate(sortedAsc.last);
    }

    return UserStreak(
      currentStreak: current,
      longestStreak: longest,
      lastCheckInDate: latestDateStr,
      checkedInToday: checkedInToday,
    );
  }

  /// Checks if user already checked in for today
  Future<bool> hasCheckedInToday({
    required String uid,
    String? familyId,
  }) async {
    try {
      final String todayStr = formatDate(now);
      final QuerySnapshot<Map<String, dynamic>> snap = await _firestore
          .collection('checkins')
          .where('uid', isEqualTo: uid)
          .where('localDate', isEqualTo: todayStr)
          .get();

      if (familyId != null && familyId.isNotEmpty) {
        return snap.docs.any((doc) => doc.data()['familyId'] == familyId);
      }
      return snap.docs.isNotEmpty;
    } catch (e) {
      debugPrint('StreakService.hasCheckedInToday error: $e');
      return false;
    }
  }

  /// Fetches the last 60 days of check-ins for [uid] and computes their streak.
  Future<UserStreak> getUserStreak({
    required String uid,
    String? familyId,
  }) async {
    try {
      final DateTime cutoff = now.subtract(const Duration(days: 60));
      final QuerySnapshot<Map<String, dynamic>> snap = await _firestore
          .collection('checkins')
          .where('uid', isEqualTo: uid)
          .get();

      final List<String> localDates = snap.docs
          .where((doc) {
            final data = doc.data();
            if (familyId != null &&
                familyId.isNotEmpty &&
                data['familyId'] != familyId) {
              return false;
            }
            final dynamic ts = data['timestamp'];
            if (ts is Timestamp && ts.toDate().isBefore(cutoff)) {
              return false;
            }
            return true;
          })
          .map((doc) => doc.data()['localDate'] as String?)
          .whereType<String>()
          .toList();

      return calculateStreak(
        localDates: localDates,
        referenceNow: now,
      );
    } catch (e) {
      debugPrint('StreakService.getUserStreak error: $e');
      return const UserStreak();
    }
  }

  /// Performs a check-in for the user today.
  /// Returns a record with (success: bool, newStreak: int, celebratedMilestone: int?).
  Future<({bool success, int newStreak, int? celebratedMilestone})> checkIn({
    required String uid,
    required String familyId,
    required String displayName,
    List<String> otherFamilyMemberIds = const <String>[],
  }) async {
    final String todayStr = formatDate(now);

    // One check-in per user per day: check if already exists
    final bool alreadyDone = await hasCheckedInToday(
      uid: uid,
      familyId: familyId,
    );

    if (alreadyDone) {
      final streak = await getUserStreak(uid: uid, familyId: familyId);
      return (
        success: false,
        newStreak: streak.currentStreak,
        celebratedMilestone: null
      );
    }

    await HapticFeedback.lightImpact();

    final Map<String, dynamic> checkinDoc = <String, dynamic>{
      'uid': uid,
      'familyId': familyId,
      'displayName': displayName,
      'timestamp': FieldValue.serverTimestamp(),
      'localDate': todayStr,
    };

    await _firestore.collection('checkins').add(checkinDoc);

    // Calculate new streak
    final UserStreak newStreakData = await getUserStreak(
      uid: uid,
      familyId: familyId,
    );
    final int currentStreak = newStreakData.currentStreak;

    int? milestoneHit;
    for (final int milestone in streakMilestones) {
      if (currentStreak >= milestone) {
        final bool celebrated = await _checkAndMarkMilestoneCelebrated(
          uid: uid,
          milestone: milestone,
        );
        if (celebrated) {
          milestoneHit = milestone;
          await _broadcastMilestoneAlert(
            familyId: familyId,
            triggeredByUid: uid,
            triggeredByName: displayName,
            milestone: milestone,
            otherMemberIds: otherFamilyMemberIds,
          );
          break;
        }
      }
    }

    return (
      success: true,
      newStreak: currentStreak,
      celebratedMilestone: milestoneHit
    );
  }

  /// Checks SharedPreferences to see if milestone has fired. Returns true if newly celebrated.
  Future<bool> _checkAndMarkMilestoneCelebrated({
    required String uid,
    required int milestone,
  }) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String key = 'celebrated_streak_${uid}_$milestone';
      if (prefs.getBool(key) == true) {
        return false;
      }
      await prefs.setBool(key, true);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Writes an alert doc per other family member into alerts collection via WriteBatch.
  Future<void> _broadcastMilestoneAlert({
    required String familyId,
    required String triggeredByUid,
    required String triggeredByName,
    required int milestone,
    required List<String> otherMemberIds,
  }) async {
    if (otherMemberIds.isEmpty) return;

    try {
      final WriteBatch batch = _firestore.batch();
      for (final String memberId in otherMemberIds) {
        if (memberId == triggeredByUid) continue;
        final DocumentReference alertDoc = _firestore.collection('alerts').doc();
        batch.set(alertDoc, <String, dynamic>{
          'userId': memberId,
          'familyId': familyId,
          'triggeredByUid': triggeredByUid,
          'triggeredByName': triggeredByName,
          'title': '$triggeredByName hit a $milestone-day streak',
          'message': '$triggeredByName hit a $milestone-day streak',
          'timestamp': FieldValue.serverTimestamp(),
          'type': 'streak',
          'seen': false,
        });
      }
      await batch.commit();
      if (kDebugMode) {
        debugPrint(
            'StreakService: Dispatched milestone $milestone alert to ${otherMemberIds.length} members');
      }
    } catch (e) {
      debugPrint('StreakService: Failed to broadcast milestone alerts: $e');
    }
  }

  /// Loads leaderboard for all circle members, sorted by currentStreak descending, then longestStreak.
  Future<List<LeaderboardEntry>> getFamilyLeaderboard({
    required String familyId,
    required List<AppUser> members,
  }) async {
    if (members.isEmpty) {
      return <LeaderboardEntry>[];
    }

    final List<LeaderboardEntry> entries = <LeaderboardEntry>[];
    for (final AppUser member in members) {
      final UserStreak streak = await getUserStreak(
        uid: member.uid,
        familyId: familyId,
      );
      entries.add(LeaderboardEntry(
        member: member,
        currentStreak: streak.currentStreak,
        longestStreak: streak.longestStreak,
        checkedInToday: streak.checkedInToday,
      ));
    }

    // Sort descending by currentStreak, then longestStreak, then name
    entries.sort((a, b) {
      final int cmpCurrent = b.currentStreak.compareTo(a.currentStreak);
      if (cmpCurrent != 0) return cmpCurrent;
      final int cmpLongest = b.longestStreak.compareTo(a.longestStreak);
      if (cmpLongest != 0) return cmpLongest;
      return a.member.displayName.compareTo(b.member.displayName);
    });

    return entries;
  }
}
