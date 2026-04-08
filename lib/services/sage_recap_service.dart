import 'dart:async' show Future;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SageRecapService {
  SageRecapService._();

  static final SageRecapService instance = SageRecapService._();
  static const String _lastRecapDateKey = 'sage_last_recap_date';

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _recapRanThisSession = false;

  bool get recapRanThisSession => _recapRanThisSession;

  Future<void> maybeRunRecap() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) {
        return;
      }

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      if (today.weekday != DateTime.monday) {
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final lastRecapDateIso = prefs.getString(_lastRecapDateKey);
      if (lastRecapDateIso != null) {
        final parsedLastRecapDate = DateTime.tryParse(lastRecapDateIso);
        if (parsedLastRecapDate != null) {
          final lastRecapDate = DateTime(
            parsedLastRecapDate.year,
            parsedLastRecapDate.month,
            parsedLastRecapDate.day,
          );
          final daysSinceLastRecap = today.difference(lastRecapDate).inDays;
          if (daysSinceLastRecap <= 6) {
            return;
          }
        }
      }

      final sevenDaysAgo = now.subtract(const Duration(days: 7));
      final logsSnapshot = await _firestore
          .collection('wellbeingLogs')
          .where('userId', isEqualTo: uid)
          .where(
            'createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(sevenDaysAgo),
          )
          .limit(200)
          .get();

      if (logsSnapshot.docs.isEmpty) {
        return;
      }

      double moodSum = 0;
      int moodCount = 0;
      final emotionCounts = <String, int>{};

      for (final doc in logsSnapshot.docs) {
        final data = doc.data();

        final moodValue = _toMoodValue(data['mood']);
        if (moodValue != null) {
          moodSum += moodValue.clamp(1.0, 5.0).toDouble();
          moodCount += 1;
        }

        final rawEmotion = data['emotion'];
        final emotion = rawEmotion is String && rawEmotion.trim().isNotEmpty
            ? rawEmotion.trim()
            : 'unknown';
        emotionCounts[emotion] = (emotionCounts[emotion] ?? 0) + 1;
      }

      final avgMood = moodCount > 0
          ? (moodSum / moodCount).clamp(1.0, 5.0).toDouble()
          : 3.0;
      final totalCheckIns = logsSnapshot.docs.length;
      final dominantEmotion = _dominantEmotion(emotionCounts);
      final mondayOfCurrentWeek =
          today.subtract(Duration(days: today.weekday - DateTime.monday));
      final weekStart = mondayOfCurrentWeek.toIso8601String().split('T').first;

      await _firestore
          .collection('sageSummaries')
          .doc(uid)
          .collection('weeks')
          .doc(weekStart)
          .set({
        'userId': uid,
        'weekStart': weekStart,
        'avgMood': avgMood,
        'totalCheckIns': totalCheckIns,
        'dominantEmotion': dominantEmotion,
        'generatedAt': FieldValue.serverTimestamp(),
        'source': 'device',
      });

      await prefs.setString(_lastRecapDateKey, today.toIso8601String());
      _recapRanThisSession = true;
    } catch (error, stackTrace) {
      debugPrint('SageRecapService maybeRunRecap failed: $error');
      debugPrint('$stackTrace');
    }
  }

  double? _toMoodValue(Object? rawMood) {
    if (rawMood is num) {
      return rawMood.toDouble();
    }
    if (rawMood is String) {
      return double.tryParse(rawMood);
    }
    return null;
  }

  String _dominantEmotion(Map<String, int> emotionCounts) {
    if (emotionCounts.isEmpty) {
      return 'unknown';
    }

    String dominant = 'unknown';
    int highestCount = 0;
    for (final entry in emotionCounts.entries) {
      if (entry.value > highestCount) {
        dominant = entry.key;
        highestCount = entry.value;
      }
    }

    return dominant;
  }
}
