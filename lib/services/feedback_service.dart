import 'package:cloud_firestore/cloud_firestore.dart';

class FeedbackService {
  FeedbackService._private();
  static final FeedbackService _instance = FeedbackService._private();
  factory FeedbackService() => _instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> submitAlertFeedback({
    required String alertId,
    required String userId,
    required bool helpful,
  }) async {
    await _firestore.collection('alert_feedback').add({
      'alertId': alertId,
      'userId': userId,
      'feedback': helpful ? 'helpful' : 'not_helpful',
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
}
 