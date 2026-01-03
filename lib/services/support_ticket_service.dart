import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class SupportTicketService {
  SupportTicketService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FirebaseStorage? storage,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FirebaseStorage _storage;

  Future<String> createTicket({
    required String name,
    required String email,
    required String subject,
    required String description,
    File? screenshot,
  }) async {
    final uid = _auth.currentUser?.uid;
    String? screenshotUrl;

    if (screenshot != null) {
      final fileName = 'support/${DateTime.now().millisecondsSinceEpoch}_${screenshot.path.split('/').last}';
      final ref = _storage.ref().child(fileName);
      await ref.putFile(screenshot);
      screenshotUrl = await ref.getDownloadURL();
    }

    final doc = await _firestore.collection('support_tickets').add({
      'uid': uid,
      'name': name.trim(),
      'email': email.trim(),
      'subject': subject.trim(),
      'description': description.trim(),
      'screenshotUrl': screenshotUrl,
      'status': 'open',
      'createdAt': FieldValue.serverTimestamp(),
    });

    return doc.id;
  }
}
