import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'streak_service.dart';

/// Single event in a member's daily timeline
class TimelineEvent {
  final String type;
  final String title;
  final String subtitle;
  final DateTime? timestamp;

  const TimelineEvent({
    required this.type,
    required this.title,
    required this.subtitle,
    this.timestamp,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimelineEvent &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          title == other.title &&
          subtitle == other.subtitle &&
          timestamp == other.timestamp;

  @override
  int get hashCode =>
      type.hashCode ^ title.hashCode ^ subtitle.hashCode ^ timestamp.hashCode;

  @override
  String toString() =>
      'TimelineEvent(type: $type, title: $title, subtitle: $subtitle, timestamp: $timestamp)';
}

/// Service fetching and merging events for a member's day
class MemberTimelineService {
  /// Truncate long subtitles to 80 characters + '…'
  static String truncateSubtitle(String msg) {
    if (msg.length > 80) {
      return '${msg.substring(0, 80)}…';
    }
    return msg;
  }

  /// Maps a Firestore checkin document data to a TimelineEvent
  static TimelineEvent mapCheckinDoc(Map<String, dynamic> data) {
    final DateTime? ts = (data['timestamp'] as Timestamp?)?.toDate();
    return TimelineEvent(
      type: 'checkin',
      title: "Checked in — I'm OK",
      subtitle: '',
      timestamp: ts,
    );
  }

  /// Maps a Firestore alert document data to a TimelineEvent
  static TimelineEvent mapAlertDoc(Map<String, dynamic> data) {
    final String rawType = (data['type'] ?? 'alert').toString();
    final String rawTitle = (data['title'] ?? 'Alert').toString();
    final String rawMsg = (data['message'] ?? '').toString();
    final DateTime? ts = (data['timestamp'] as Timestamp?)?.toDate();

    return TimelineEvent(
      type: rawType,
      title: rawTitle,
      subtitle: truncateSubtitle(rawMsg),
      timestamp: ts,
    );
  }

  /// Merges two event lists and sorts them descending by timestamp, nulls last.
  static List<TimelineEvent> mergeAndSort(
    List<TimelineEvent> a,
    List<TimelineEvent> b,
  ) {
    final List<TimelineEvent> combined = <TimelineEvent>[...a, ...b];
    combined.sort((TimelineEvent x, TimelineEvent y) {
      if (x.timestamp == null && y.timestamp == null) return 0;
      if (x.timestamp == null) return 1; // nulls last
      if (y.timestamp == null) return -1;
      return y.timestamp!.compareTo(x.timestamp!); // descending
    });
    return combined;
  }

  /// Fetches check-ins and alerts for a member today, returning a merged sorted timeline.
  static Future<List<TimelineEvent>> getMemberTimeline({
    required String uid,
    required String familyId,
    FirebaseFirestore? firestore,
    DateTime? now,
  }) async {
    final FirebaseFirestore db = firestore ?? FirebaseFirestore.instance;
    final DateTime currentNow = now ?? DateTime.now();
    final String todayStr = StreakService.formatDate(currentNow);
    final DateTime startOfToday = DateTime(
      currentNow.year,
      currentNow.month,
      currentNow.day,
    );

    // 1. Query checkins
    final List<TimelineEvent> checkinEvents = <TimelineEvent>[];
    try {
      final QuerySnapshot<Map<String, dynamic>> checkinSnap = await db
          .collection('checkins')
          .where('uid', isEqualTo: uid)
          .where('familyId', isEqualTo: familyId)
          .where('localDate', isEqualTo: todayStr)
          .get();

      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in checkinSnap.docs) {
        checkinEvents.add(mapCheckinDoc(doc.data()));
      }
    } catch (e) {
      debugPrint('MemberTimelineService checkins query error: ');
    }

    // 2. Query alerts
    final List<TimelineEvent> alertEvents = <TimelineEvent>[];
    try {
      final QuerySnapshot<Map<String, dynamic>> alertSnap = await db
          .collection('alerts')
          .where('triggeredByUid', isEqualTo: uid)
          .where('familyId', isEqualTo: familyId)
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfToday))
          .get();

      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in alertSnap.docs) {
        alertEvents.add(mapAlertDoc(doc.data()));
      }
    } catch (e) {
      debugPrint('MemberTimelineService alerts query error: ');
    }

    return mergeAndSort(checkinEvents, alertEvents);
  }
}
