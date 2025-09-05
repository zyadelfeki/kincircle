import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/family.dart';
import 'sendgrid_service.dart';
import 'telemetry_service.dart';

class FirestoreService {
  FirestoreService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    String? Function()? currentUidProvider,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth,
        _currentUidProvider = currentUidProvider;

  final FirebaseFirestore _firestore;
  final FirebaseAuth? _auth;
  final String? Function()? _currentUidProvider;

  /// Get the current user's UID
  String? getCurrentUid() => _currentUid();

  String? _currentUid() => _currentUidProvider != null
      ? _currentUidProvider!()
      : (_auth ?? FirebaseAuth.instance).currentUser?.uid;

  Future<bool> hasCurrentFamily() async {
    final uid = _currentUid();
    if (uid == null) return false;
    final userDoc = await _firestore.collection('users').doc(uid).get();
    final familyId = userDoc.data()?['currentFamilyId'];
    return familyId != null && (familyId as String).isNotEmpty;
  }

  Future<String?> getCurrentFamilyId() async {
    final uid = _currentUid();
    if (uid == null) return null;
    final userDoc = await _firestore.collection('users').doc(uid).get();
    final familyId = userDoc.data()?['currentFamilyId'];
    return familyId is String && familyId.isNotEmpty ? familyId : null;
  }

  Future<String> createFamily({required String name}) async {
    final uid = _currentUid();
    if (uid == null) {
      throw Exception('User not authenticated');
    }
    final famRef = await _firestore.collection('families').add({
      'name': name.trim().isEmpty ? 'Family' : name.trim(),
      'members': [uid],
      'ownerId': uid, // Explicit owner field for new families
      'createdAt': FieldValue.serverTimestamp(),
    });
    await _firestore
        .collection('users')
        .doc(uid)
        .update({'currentFamilyId': famRef.id});
    return famRef.id;
  }

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

    final ref = await _firestore.collection('invites').add({
      'recipientEmail': email.trim(),
      'senderUid': uid,
      'familyId': familyId,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
    // Attempt direct SendGrid REST (preferred per blueprint). Expect API key via String.fromEnvironment.
  const apiKey = String.fromEnvironment('SENDGRID_API_KEY', defaultValue: '');
  const fromEmail = String.fromEnvironment('FROM_EMAIL', defaultValue: 'no-reply@kincircle.app');
    if (apiKey.isNotEmpty) {
      try {
  final link = 'https://links.kincircle.app/invite/${ref.id}';
  final sg = SendGridService(apiKey: apiKey, fromEmail: fromEmail, fromName: 'KinCircle');
  const subject = "You're invited to join KinCircle";
  final html = '<h2 style="color:#2E86AB;margin:0 0 16px">KinCircle Invitation</h2>'
            '<p>You\'ve been invited to join a family on KinCircle.</p>'
            '<p><a href="$link" style="background:#2E86AB;color:#fff;padding:12px 16px;border-radius:8px;text-decoration:none">Accept Invite</a></p>'
            '<p>Or open this link: <a href="$link">$link</a></p>';
        await sg.sendEmail(toEmail: email.trim(), subject: subject, html: html);
        return;
      } catch (_) {
        // Fall back to callable below
      }
    }
    // Fallback: Cloud Function callable (if configured)
    try {
      await FirebaseFunctions.instance.httpsCallable('sendInviteEmail').call({'to': email.trim(), 'inviteId': ref.id});
    } catch (_) {}
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

  /// Remove a member from the family. Only callable by the family owner (first member in the members array).
  Future<void> removeMember(String familyId, String memberUidToRemove) async {
    final uid = _currentUid();
    if (uid == null) {
      throw Exception('User not authenticated');
    }

    await _firestore.runTransaction((txn) async {
      final familyRef = _firestore.collection('families').doc(familyId);
      final familySnap = await txn.get(familyRef);
      
      if (!familySnap.exists) {
        throw Exception('Family not found');
      }

      final familyData = familySnap.data() as Map<String, dynamic>;
      final members = List<String>.from(familyData['members'] ?? []);
      
      // Check if the current user is the family owner
      if (familyData['ownerId'] != uid) {
        throw Exception('Only the family owner can remove members');
      }

      // Prevent owner from removing themselves
      if (memberUidToRemove == uid) {
        throw Exception('Family owner cannot remove themselves');
      }

      // Remove the member from the family
      if (members.contains(memberUidToRemove)) {
        members.remove(memberUidToRemove);
        txn.update(familyRef, {'members': members});

        // Remove the family reference from the member's user document
        final memberRef = _firestore.collection('users').doc(memberUidToRemove);
        txn.update(memberRef, {'currentFamilyId': FieldValue.delete()});
      } else {
        throw Exception('User is not a member of this family');
      }
    });
  }

  /// Leave the current family. Only callable by non-owner members.
  Future<void> leaveFamily(String familyId) async {
    final uid = _currentUid();
    if (uid == null) {
      throw Exception('User not authenticated');
    }

    await _firestore.runTransaction((txn) async {
      final familyRef = _firestore.collection('families').doc(familyId);
      final familySnap = await txn.get(familyRef);
      
      if (!familySnap.exists) {
        throw Exception('Family not found');
      }

      final familyData = familySnap.data() as Map<String, dynamic>;
      final members = List<String>.from(familyData['members'] ?? []);
      
      // Check if the user is the family owner
      if (familyData['ownerId'] == uid) {
        throw Exception('Family owner cannot leave the family. Transfer ownership or delete the family instead.');
      }

      // Remove the current user from the family
      if (members.contains(uid)) {
        members.remove(uid);
        txn.update(familyRef, {'members': members});

        // Remove the family reference from the user's document
        final userRef = _firestore.collection('users').doc(uid);
        txn.update(userRef, {'currentFamilyId': FieldValue.delete()});
      } else {
        throw Exception('You are not a member of this family');
      }
    });
  }

  /// Get family details including all members information
  Future<Map<String, dynamic>?> getFamilyDetails(String familyId) async {
    final familyDoc = await _firestore.collection('families').doc(familyId).get();
    if (!familyDoc.exists) {
      return null;
    }

    final familyData = familyDoc.data() as Map<String, dynamic>;
    final members = List<String>.from(familyData['members'] ?? []);
    
    // Fetch user details for all members
    final memberDetails = <Map<String, dynamic>>[];
    for (final memberId in members) {
      final userDoc = await _firestore.collection('users').doc(memberId).get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        memberDetails.add({
          'uid': memberId,
          'email': userData['email'] ?? '',
          'displayName': userData['displayName'] ?? userData['email'] ?? 'Unknown User',
          'isOwner': familyData['ownerId'] == memberId,
        });
      }
    }

    return {
      'id': familyId,
      'name': familyData['name'] ?? 'Family',
      'members': memberDetails,
      'createdAt': familyData['createdAt'],
      'ownerId': familyData['ownerId'], // Include ownerId in returned data
    };
  }

  /// Get family as a model object
  Future<Family?> getFamily(String familyId) async {
    final familyDoc = await _firestore.collection('families').doc(familyId).get();
    if (!familyDoc.exists) {
      return null;
    }

    final familyData = familyDoc.data() as Map<String, dynamic>;

    return Family.fromMap(familyId, familyData);
  }
}
