import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'telemetry_service.dart';

class FirestoreService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth? _auth;
  final String? Function()? _currentUidProvider;

  FirestoreService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  String? Function()? currentUidProvider,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth,
        _currentUidProvider = currentUidProvider;

  String? _currentUid() => _currentUidProvider != null
      ? _currentUidProvider!()
      : (_auth ?? FirebaseAuth.instance).currentUser?.uid;

  /// Sends an invite to [email] by creating a document in the top-level
  /// `invites` collection. Each document contains:
  ///   - recipientEmail : The email to invite
  ///   - senderUid      : The UID of the currently authenticated user
  ///   - familyId       : The sender's current family ID
  ///   - status         : pending / accepted / declined (default: pending)
  ///   - createdAt      : server timestamp
  ///
  /// Throws [Exception] if no authenticated user is found or the user does not
  /// yet belong to a family.
  Future<void> sendInvite({required String email}) async {
    final uid = _currentUid();
    if (uid == null) {
      throw Exception('User not authenticated');
    }

    // Fetch user's familyId from their profile
    final userDoc = await _firestore.collection('users').doc(uid).get();
    final familyId = userDoc.data()?['currentFamilyId'];
    if (familyId == null) {
      throw Exception('You must create or join a family first.');
    }

    await _firestore.collection('invites').add({
      'recipientEmail': email.trim(),
      'senderUid': uid,
      'familyId': familyId,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateVisibility({required bool isInvisible}) async {
  final uid = _currentUid();
  if (uid == null) {
      throw Exception('User not authenticated');
    }

  await _firestore.collection('users').doc(uid).update({
      'invisibleMode': isInvisible,
      'lastUpdated': FieldValue.serverTimestamp(),
    });
  }

  Future<void> acceptInvite({required String inviteId}) async {
  final uid = _currentUid();
    if (uid == null) {
      throw FirebaseAuthException(
          code: 'not-authenticated', message: 'User must be logged in');
    }

    final inviteRef = _firestore.collection('invites').doc(inviteId);

    await _firestore.runTransaction((txn) async {
      final inviteSnap = await txn.get(inviteRef);
      if (!inviteSnap.exists) {
        throw Exception('Invite not found');
      }
      final inviteData = inviteSnap.data() as Map<String, dynamic>;
      final familyId = inviteData['familyId'] as String?;
      if (familyId == null) {
        throw Exception('Malformed invite – missing familyId');
      }

      final familyRef = _firestore.collection('families').doc(familyId);
      final userRef = _firestore.collection('users').doc(uid);

      txn.update(familyRef, {
        'members': FieldValue.arrayUnion([uid])
      });
      txn.update(userRef, {
        'currentFamilyId': familyId,
      });
      txn.delete(inviteRef);
    });

    // Log analytics event for acceptance (sampled)
    await TelemetryService(firestore: _firestore).logInviteEvent(
      inviteId: inviteId,
      event: 'accepted',
      uid: uid,
    );
  }

  /// Generates an invite document and returns its ID for sharing (QR/link).
  /// Requires an authenticated user who belongs to a family (currentFamilyId).
  Future<String> generateInviteId() async {
    final uid = _currentUid();
    if (uid == null) {
      throw Exception('User not authenticated');
    }
    final userDoc = await _firestore.collection('users').doc(uid).get();
    final familyId = userDoc.data()?['currentFamilyId'] as String?;
    if (familyId == null || familyId.isEmpty) {
      throw Exception('You must create or join a family first.');
    }
    final ref = await _firestore.collection('invites').add({
      'senderUid': uid,
      'familyId': familyId,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }
}
