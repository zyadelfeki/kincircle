import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/emergency_contact.dart';

/// Risk levels that trigger different emergency response cascades
enum EmergencyRiskLevel {
  medium,  // Notify primary family contacts
  high,    // Notify family + medical professionals
  critical, // Full cascade: family + medical + first responders
}

/// Result of an emergency response notification
class EmergencyResponseResult {
  final String contactId;
  final String contactName;
  final bool success;
  final String? error;

  EmergencyResponseResult({
    required this.contactId,
    required this.contactName,
    required this.success,
    this.error,
  });
}

/// Service for coordinating emergency responses based on risk levels
class EmergencyResponseService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  EmergencyResponseService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  /// Trigger an emergency response based on risk level
  Future<List<EmergencyResponseResult>> triggerEmergencyResponse({
    required EmergencyRiskLevel riskLevel,
    required String reason,
    Map<String, dynamic>? metadata,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User must be authenticated to trigger emergency response');
    }

    // Get emergency contacts
    final contacts = await _getEmergencyContacts(user.uid);
    
    // Filter contacts based on risk level
    final contactsToNotify = _filterContactsByRiskLevel(contacts, riskLevel);

    // Sort contacts by priority
    contactsToNotify.sort((a, b) {
      final priorityOrder = {
        EmergencyContactPriority.primary: 0,
        EmergencyContactPriority.secondary: 1,
        EmergencyContactPriority.tertiary: 2,
      };
      return (priorityOrder[a.priority] ?? 999)
          .compareTo(priorityOrder[b.priority] ?? 999);
    });

    // Log the emergency event
    await _logEmergencyEvent(
      userId: user.uid,
      riskLevel: riskLevel,
      reason: reason,
      contactIds: contactsToNotify.map((c) => c.id).toList(),
      metadata: metadata,
    );

    // Notify contacts
    final results = <EmergencyResponseResult>[];
    for (final contact in contactsToNotify) {
      final result = await _notifyContact(
        contact: contact,
        riskLevel: riskLevel,
        reason: reason,
        metadata: metadata,
      );
      results.add(result);
    }

    return results;
  }

  /// Get all emergency contacts for a user
  Future<List<EmergencyContact>> _getEmergencyContacts(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('emergency_contacts')
          .where('userId', isEqualTo: userId)
          .orderBy('priority')
          .get();

      return snapshot.docs
          .map((doc) => EmergencyContact.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error fetching emergency contacts: $e');
      return [];
    }
  }

  /// Filter contacts based on risk level
  List<EmergencyContact> _filterContactsByRiskLevel(
    List<EmergencyContact> contacts,
    EmergencyRiskLevel riskLevel,
  ) {
    switch (riskLevel) {
      case EmergencyRiskLevel.medium:
        // Only notify primary family contacts
        return contacts.where((c) =>
          c.type == EmergencyContactType.family &&
          c.priority == EmergencyContactPriority.primary
        ).toList();

      case EmergencyRiskLevel.high:
        // Notify family + medical professionals
        return contacts.where((c) =>
          c.type == EmergencyContactType.family ||
          c.type == EmergencyContactType.medical
        ).toList();

      case EmergencyRiskLevel.critical:
        // Full cascade: all contacts
        return contacts;
    }
  }

  /// Notify a single contact (placeholder for actual notification logic)
  Future<EmergencyResponseResult> _notifyContact({
    required EmergencyContact contact,
    required EmergencyRiskLevel riskLevel,
    required String reason,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      // In a real implementation, this would:
      // - Send SMS via Twilio/AWS SNS if notifyBySms is true
      // - Make phone call via Twilio if notifyByPhone is true
      // - Send email via SendGrid/AWS SES if notifyByEmail is true
      
      // For now, we'll create a notification record in Firestore
      await _firestore.collection('emergency_notifications').add({
        'contactId': contact.id,
        'contactName': contact.name,
        'phoneNumber': contact.phoneNumber,
        'email': contact.email,
        'riskLevel': riskLevel.name,
        'reason': reason,
        'metadata': metadata,
        'notifyByPhone': contact.notifyByPhone,
        'notifyByEmail': contact.notifyByEmail,
        'notifyBySms': contact.notifyBySms,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending',
      });

      debugPrint('Emergency notification sent to ${contact.name}');

      return EmergencyResponseResult(
        contactId: contact.id,
        contactName: contact.name,
        success: true,
      );
    } catch (e) {
      debugPrint('Error notifying contact ${contact.name}: $e');
      return EmergencyResponseResult(
        contactId: contact.id,
        contactName: contact.name,
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Log emergency event for audit trail
  Future<void> _logEmergencyEvent({
    required String userId,
    required EmergencyRiskLevel riskLevel,
    required String reason,
    required List<String> contactIds,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await _firestore.collection('emergency_events').add({
        'userId': userId,
        'riskLevel': riskLevel.name,
        'reason': reason,
        'contactIds': contactIds,
        'metadata': metadata,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error logging emergency event: $e');
    }
  }

  /// Get emergency contacts for display
  Stream<List<EmergencyContact>> getEmergencyContacts() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('emergency_contacts')
        .where('userId', isEqualTo: user.uid)
        .orderBy('priority')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => EmergencyContact.fromFirestore(doc))
            .toList());
  }

  /// Add a new emergency contact
  Future<String> addEmergencyContact(EmergencyContact contact) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User must be authenticated to add emergency contact');
    }

    final docRef = await _firestore.collection('emergency_contacts').add(
      contact.copyWith(
        userId: user.uid,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ).toFirestore(),
    );

    return docRef.id;
  }

  /// Update an existing emergency contact
  Future<void> updateEmergencyContact(EmergencyContact contact) async {
    await _firestore
        .collection('emergency_contacts')
        .doc(contact.id)
        .update(contact.copyWith(updatedAt: DateTime.now()).toFirestore());
  }

  /// Delete an emergency contact
  Future<void> deleteEmergencyContact(String contactId) async {
    await _firestore.collection('emergency_contacts').doc(contactId).delete();
  }
}
