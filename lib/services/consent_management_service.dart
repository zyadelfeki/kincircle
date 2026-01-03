import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Records GDPR consent decisions with complete audit metadata.
class ConsentManagementService {
  ConsentManagementService._();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Records a consent decision for [userId].
  static Future<void> recordConsent({
    required String userId,
    required ConsentType type,
    required bool granted,
    String? details,
  }) async {
    final Map<String, dynamic> consent = <String, dynamic>{
      'type': type.name,
      'granted': granted,
      'timestamp': FieldValue.serverTimestamp(),
      'details': details,
      'ip_address': await _getIpAddress(),
      'user_agent': await _getUserAgent(),
    };

    await _firestore
        .collection('users')
        .doc(userId)
        .collection('consents')
        .add(consent);

    await _firestore.collection('users').doc(userId).set(<String, dynamic>{
      'consent_status.${type.name}': granted,
      'consent_status.updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Convenience overload to record consent for the currently authenticated user.
  static Future<void> recordCurrentUserConsent({
    required ConsentType type,
    required bool granted,
    String? details,
  }) async {
    final User? user = _auth.currentUser;
    if (user == null) {
      throw StateError('No authenticated user to record consent');
    }
    await recordConsent(
      userId: user.uid,
      type: type,
      granted: granted,
      details: details,
    );
  }

  /// Returns the latest consent state for all consent categories.
  static Future<Map<ConsentType, bool>> getConsentStatus(String userId) async {
    final DocumentSnapshot<Map<String, dynamic>> doc =
        await _firestore.collection('users').doc(userId).get();
    final Map<String, dynamic> data = doc.data() ?? <String, dynamic>{};
    final Map<String, dynamic> consentStatus =
        data['consent_status'] as Map<String, dynamic>? ?? <String, dynamic>{};

    return <ConsentType, bool>{
      for (final ConsentType type in ConsentType.values)
        type: consentStatus[type.name] as bool? ?? false,
    };
  }

  /// Withdraws consent and optionally purges associated processed data.
  static Future<void> withdrawConsent({
    required String userId,
    required ConsentType type,
    String? reason,
  }) async {
    await recordConsent(
      userId: userId,
      type: type,
      granted: false,
      details: 'Withdrawn: $reason',
    );

    if (type == ConsentType.dataProcessing ||
        type == ConsentType.aiProcessing) {
      await _deleteProcessedData(userId);
    }
  }

  static Future<void> _deleteProcessedData(String userId) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('wellbeing_analytics')
        .get();
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
        in snapshot.docs) {
      await doc.reference.delete();
    }
  }

  static Future<String> _getIpAddress() async {
    // In production we would hit a Cloud Function or trusted edge endpoint.
    return 'N/A';
  }

  static Future<String> _getUserAgent() async {
    // Implement using device_info_plus if desired.
    return 'Flutter App';
  }
}

enum ConsentType {
  dataProcessing,
  locationTracking,
  analytics,
  marketing,
  thirdPartySharing,
  aiProcessing,
  healthData,
}
