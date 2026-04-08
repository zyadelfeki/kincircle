import 'package:cloud_firestore/cloud_firestore.dart';

class SageSummary {
  SageSummary({
    required this.userId,
    required this.weekStart,
    required this.avgMood,
    required this.totalCheckIns,
    required this.dominantEmotion,
    this.generatedAt,
  });

  factory SageSummary.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return SageSummary(
      userId: data['userId'] as String? ?? doc.reference.parent.parent?.id ?? '',
      weekStart: data['weekStart'] as String? ?? doc.id,
      avgMood: (data['avgMood'] as num?)?.toDouble() ?? 0.0,
      totalCheckIns: (data['totalCheckIns'] as num?)?.toInt() ?? 0,
      dominantEmotion: data['dominantEmotion'] as String? ?? 'unknown',
      generatedAt: (data['generatedAt'] as Timestamp?)?.toDate(),
    );
  }

  final String userId;
  final String weekStart;
  final double avgMood;
  final int totalCheckIns;
  final String dominantEmotion;
  final DateTime? generatedAt;

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'weekStart': weekStart,
      'avgMood': avgMood,
      'totalCheckIns': totalCheckIns,
      'dominantEmotion': dominantEmotion,
      'generatedAt':
          generatedAt != null ? Timestamp.fromDate(generatedAt!) : null,
    };
  }
}
