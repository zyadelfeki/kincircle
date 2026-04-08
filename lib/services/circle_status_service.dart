import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

enum CircleMemberStatus { safe, needsHelp, unknown }

class CircleMemberStatusEntry {
  const CircleMemberStatusEntry({
    required this.uid,
    required this.status,
    required this.updatedAt,
  });

  final String uid;
  final CircleMemberStatus status;
  final DateTime? updatedAt;
}

class CircleStatusService {
  CircleStatusService._();

  static final CircleStatusService instance = CircleStatusService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> broadcastStatus(CircleMemberStatus status) async {
    try {
      final String? uid = _auth.currentUser?.uid;
      if (uid == null || uid.isEmpty) {
        debugPrint('CircleStatusService: Cannot broadcast status, no user');
        return;
      }

      final String? circleId = await _getCurrentCircleId(uid);
      if (circleId == null || circleId.isEmpty) {
        debugPrint('CircleStatusService: Cannot broadcast status, no circleId for $uid');
        return;
      }

      await _firestore.collection('circleStatus').doc(uid).set(
        <String, dynamic>{
          'uid': uid,
          'circleId': circleId,
          'status': _statusToString(status),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('CircleStatusService broadcastStatus error: $e');
    }
  }

  Stream<List<CircleMemberStatusEntry>> watchCircleStatuses(String circleId) {
    try {
      if (circleId.isEmpty) {
        return const Stream<List<CircleMemberStatusEntry>>.empty();
      }

      return _firestore
          .collection('circleStatus')
          .where('circleId', isEqualTo: circleId)
          .snapshots()
          .map((QuerySnapshot<Map<String, dynamic>> snapshot) {
        try {
          return snapshot.docs.map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
            final Map<String, dynamic> data = doc.data();
            final Timestamp? ts = data['updatedAt'] as Timestamp?;
            return CircleMemberStatusEntry(
              uid: (data['uid'] as String?) ?? doc.id,
              status: _statusFromString((data['status'] as String?) ?? 'unknown'),
              updatedAt: ts?.toDate(),
            );
          }).toList();
        } catch (e) {
          debugPrint('CircleStatusService map status snapshot error: $e');
          return <CircleMemberStatusEntry>[];
        }
      }).handleError((Object error) {
        debugPrint('CircleStatusService watch stream error: $error');
      });
    } catch (e) {
      debugPrint('CircleStatusService watchCircleStatuses error: $e');
      return const Stream<List<CircleMemberStatusEntry>>.empty();
    }
  }

  Future<String?> _getCurrentCircleId(String uid) async {
    try {
      final DocumentSnapshot<Map<String, dynamic>> doc =
          await _firestore.collection('users').doc(uid).get();
      return doc.data()?['circleId'] as String?;
    } catch (e) {
      debugPrint('CircleStatusService getCurrentCircleId error: $e');
      return null;
    }
  }

  CircleMemberStatus _statusFromString(String status) {
    switch (status) {
      case 'safe':
        return CircleMemberStatus.safe;
      case 'needsHelp':
        return CircleMemberStatus.needsHelp;
      default:
        return CircleMemberStatus.unknown;
    }
  }

  String _statusToString(CircleMemberStatus status) {
    switch (status) {
      case CircleMemberStatus.safe:
        return 'safe';
      case CircleMemberStatus.needsHelp:
        return 'needsHelp';
      case CircleMemberStatus.unknown:
        return 'unknown';
    }
  }
}
