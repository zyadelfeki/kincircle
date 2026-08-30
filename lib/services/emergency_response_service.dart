import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/emergency_contact.dart';
import 'location_service.dart';

/// Emergency risk levels
enum EmergencyRiskLevel { low, medium, high, critical }

/// Simple emergency alert data
class EmergencyAlert {
  final double currentLat;
  final double currentLng;
  final EmergencyRiskLevel riskLevel;
  final int? estimatedTimeUntilDanger;
  final double? predictedDirection;
  final List<String> riskFactors;

  EmergencyAlert({
    required this.currentLat,
    required this.currentLng,
    required this.riskLevel,
    this.estimatedTimeUntilDanger,
    this.predictedDirection,
    this.riskFactors = const [],
  });
}

/// Emergency Response Service - AI-powered crisis coordination
class EmergencyResponseService {
  static FirebaseFirestore? _customFirestore;
  static FirebaseFirestore get _firestore =>
      _customFirestore ?? FirebaseFirestore.instance;

  @visibleForTesting
  static void setFirestoreForTesting(FirebaseFirestore? firestore) {
    _customFirestore = firestore;
  }

  /// Manual SOS trigger from press-and-hold button
  static Future<void> triggerManualSOS({
    String? userId,
    FirebaseFirestore? firestore,
    LocationService? locationService,
  }) async {
    final String? effectiveUserId =
        userId ?? FirebaseAuth.instance.currentUser?.uid;
    if (effectiveUserId == null || effectiveUserId.isEmpty) {
      debugPrint('EmergencyResponseService: No user signed in for SOS');
      return;
    }

    double currentLat = 0;
    double currentLng = 0;

    final LocationService locService = locationService ?? LocationService();
    final Position? lastWritten = locService.lastWrittenPosition;

    if (lastWritten != null) {
      currentLat = lastWritten.latitude;
      currentLng = lastWritten.longitude;
    } else {
      try {
        final Position pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            timeLimit: Duration(seconds: 5),
          ),
        );
        currentLat = pos.latitude;
        currentLng = pos.longitude;
      } catch (e) {
        debugPrint(
          '🚨 EmergencyResponseService: Location unavailable for SOS (lastWrittenPosition is null and getCurrentPosition failed: $e) — falling back to (0,0)',
        );
      }
    }

    final EmergencyAlert alert = EmergencyAlert(
      currentLat: currentLat,
      currentLng: currentLng,
      riskLevel: EmergencyRiskLevel.critical,
      riskFactors: <String>['manual_sos_button'],
    );

    await triggerEmergencyResponse(
      userId: effectiveUserId,
      alert: alert,
      firestore: firestore,
    );
  }

  Future<void> triggerCrashAlert({double? peakG, FirebaseFirestore? firestore}) async {
    final String? userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null || userId.isEmpty) {
      throw StateError('No authenticated user for crash alert');
    }

    final EmergencyAlert alert = EmergencyAlert(
      currentLat: 0,
      currentLng: 0,
      riskLevel: EmergencyRiskLevel.high,
      riskFactors: <String>[
        'crash_detected',
        if (peakG != null) 'peak_g_${peakG.toStringAsFixed(2)}',
      ],
    );

    await EmergencyResponseService.triggerEmergencyResponse(
      userId: userId,
      alert: alert,
      firestore: firestore,
    );
  }

  /// Main entry point: Trigger emergency response based on emergency alert
  static Future<EmergencyResponse> triggerEmergencyResponse({
    required String userId,
    required EmergencyAlert alert,
    FirebaseFirestore? firestore,
  }) async {
    final FirebaseFirestore db = firestore ?? _firestore;

    // Create response record
    final response = EmergencyResponse(
      responseId: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: userId,
      triggeredAt: DateTime.now(),
      riskLevel: alert.riskLevel.name,
      currentLat: alert.currentLat,
      currentLng: alert.currentLng,
    );

    // Store in Firestore (audit log)
    await db
        .collection('emergency_responses')
        .doc(response.responseId)
        .set(response.toFirestore());

    // Broadcast SOS alert documents to all other family members
    await _broadcastSosAlerts(
      firestore: db,
      userId: userId,
      alert: alert,
    );

    // Get emergency contacts
    final contacts = await getEmergencyContacts(userId, firestore: db);

    // Execute appropriate cascade based on risk level
    switch (alert.riskLevel) {
      case EmergencyRiskLevel.medium:
        await _executeMediumRiskResponse(response, contacts, alert);
        break;
      case EmergencyRiskLevel.high:
        await _executeHighRiskResponse(response, contacts, alert);
        break;
      case EmergencyRiskLevel.critical:
        await _executeCriticalRiskResponse(response, contacts, alert);
        break;
      default:
        // Low risk - no emergency response
        break;
    }

    return response;
  }

  /// Dispatches one SOS alert document per other family member into the alerts collection via WriteBatch.
  static Future<void> _broadcastSosAlerts({
    required FirebaseFirestore firestore,
    required String userId,
    required EmergencyAlert alert,
  }) async {
    try {
      // 1. Resolve user display name and current family ID
      String triggeredByName = '';
      String? familyId;

      try {
        final DocumentSnapshot<Map<String, dynamic>> userDoc =
            await firestore.collection('users').doc(userId).get();
        if (userDoc.exists) {
          final Map<String, dynamic>? userData = userDoc.data();
          triggeredByName =
              (userData?['displayName'] as String? ?? '').trim();
          familyId = userData?['currentFamilyId'] as String?;
        }
      } catch (_) {}

      if (triggeredByName.isEmpty) {
        final User? currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null && currentUser.uid == userId) {
          triggeredByName = (currentUser.displayName ?? '').trim();
          if (triggeredByName.isEmpty) {
            final String email = (currentUser.email ?? '').trim();
            if (email.contains('@')) {
              triggeredByName = email.split('@').first.trim();
            }
          }
        }
      }
      if (triggeredByName.isEmpty) {
        triggeredByName = 'Family member';
      }

      // 2. Resolve familyId if not in user doc
      if (familyId == null || familyId.isEmpty) {
        final QuerySnapshot<Map<String, dynamic>> familiesSnap = await firestore
            .collection('families')
            .where('members', arrayContains: userId)
            .limit(1)
            .get();
        if (familiesSnap.docs.isNotEmpty) {
          familyId = familiesSnap.docs.first.id;
        }
      }

      if (familyId == null || familyId.isEmpty) {
        debugPrint(
            'EmergencyResponseService: No familyId found for SOS broadcast');
        return;
      }

      // 3. Get family members
      final DocumentSnapshot<Map<String, dynamic>> familyDoc =
          await firestore.collection('families').doc(familyId).get();
      if (!familyDoc.exists) return;

      final List<String> members =
          (familyDoc.data()?['members'] as List<dynamic>? ?? <dynamic>[])
              .cast<String>();

      final List<String> otherMembers =
          members.where((uid) => uid != userId).toList();
      if (otherMembers.isEmpty) return;

      // 4. Build title and message
      final String title = '🚨 SOS — $triggeredByName needs help now';
      final String message =
          'https://maps.google.com/?q=${alert.currentLat},${alert.currentLng}';

      // 5. Write one doc per other member via WriteBatch
      final WriteBatch batch = firestore.batch();
      for (final String otherUid in otherMembers) {
        final DocumentReference docRef = firestore.collection('alerts').doc();
        batch.set(docRef, <String, dynamic>{
          'userId': otherUid,
          'familyId': familyId,
          'triggeredByUid': userId,
          'triggeredByName': triggeredByName,
          'title': title,
          'message': message,
          'timestamp': FieldValue.serverTimestamp(),
          'type': 'sos',
          'seen': false,
        });
      }
      await batch.commit();
      debugPrint(
          'EmergencyResponseService: Dispatched SOS alerts to ${otherMembers.length} family members');
    } catch (e) {
      debugPrint('EmergencyResponseService: Error broadcasting SOS alerts: $e');
    }
  }

  /// MEDIUM RISK: Contact primary family + enhanced tracking
  static Future<void> _executeMediumRiskResponse(
    EmergencyResponse response,
    List<EmergencyContact> contacts,
    EmergencyAlert alert,
  ) async {
    // 1. Contact primary family members (top 2 by priority)
    final primaryContacts = contacts
        .where((c) => c.type == EmergencyContactType.primaryFamily)
        .toList()
      ..sort((a, b) => a.priority.compareTo(b.priority));

    for (var contact in primaryContacts.take(2)) {
      await _contactPerson(contact, alert, 'MEDIUM_RISK');
    }

    // 2. Send location updates
    await _sendLocationToContacts(primaryContacts.take(2).toList(), alert);

    // 3. Activate enhanced tracking (30-second intervals)
    await _activateEnhancedTracking(response.userId);

    // 4. Schedule escalation to HIGH if not resolved in 15 minutes
    _scheduleEscalation(response.responseId, const Duration(minutes: 15));
  }

  /// HIGH RISK: Contact all family + caregivers + medical + neighbors
  static Future<void> _executeHighRiskResponse(
    EmergencyResponse response,
    List<EmergencyContact> contacts,
    EmergencyAlert alert,
  ) async {
    // 1. Contact ALL family members
    final allFamily = contacts.where((c) =>
        c.type == EmergencyContactType.primaryFamily ||
        c.type == EmergencyContactType.secondaryFamily);

    for (var contact in allFamily) {
      await _contactPerson(contact, alert, 'HIGH_RISK');
    }

    // 2. Contact caregivers
    final caregivers =
        contacts.where((c) => c.type == EmergencyContactType.caregiver);
    for (var contact in caregivers) {
      await _contactPerson(contact, alert, 'HIGH_RISK');
    }

    // 3. Alert medical professionals
    final medical = contacts
        .where((c) => c.type == EmergencyContactType.medicalProfessional);
    for (var contact in medical) {
      await _contactMedicalProfessional(contact, alert);
    }

    // 4. Notify neighbors (top 3 by proximity/priority)
    final neighbors = contacts
        .where((c) => c.type == EmergencyContactType.neighbor)
        .toList()
      ..sort((a, b) => a.priority.compareTo(b.priority));
    for (var contact in neighbors.take(3)) {
      await _contactPerson(contact, alert, 'HIGH_RISK');
    }

    // 5. Activate live location sharing
    await _activateLiveLocationSharing(response.userId, alert);

    // 6. Schedule escalation to CRITICAL if not resolved in 10 minutes
    _scheduleEscalation(response.responseId, const Duration(minutes: 10));
  }

  /// CRITICAL RISK: Immediate 911 + all contacts + emergency beacon
  static Future<void> _executeCriticalRiskResponse(
    EmergencyResponse response,
    List<EmergencyContact> contacts,
    EmergencyAlert alert,
  ) async {
    // 1. IMMEDIATE 911 CALL
    final emergency911 =
        contacts.firstWhere((c) => c.type == EmergencyContactType.emergency911,
            orElse: () => EmergencyContact(
                  id: '911',
                  name: 'Emergency Services',
                  phoneNumber: '911',
                  type: EmergencyContactType.emergency911,
                  priority: 99,
                ));

    await _call911(emergency911, alert);

    // 2. Contact ALL contacts simultaneously (parallel execution)
    final allContacts = contacts
        .where((c) => c.type != EmergencyContactType.emergency911)
        .toList();

    await Future.wait(
      allContacts.map(
        (contact) => _contactPerson(contact, alert, 'CRITICAL_EMERGENCY'),
      ),
    );

    // 3. Activate emergency beacon mode
    await _activateEmergencyBeacon(response.userId, alert);

    // 4. Broadcast medical information to all responders
    await _broadcastMedicalInfo(contacts, alert);

    // 5. Create emergency response coordination chat
    await _createEmergencyChat(response.responseId, contacts);

    // No escalation timer - already at max level
  }

  /// Contact a person using their preferred methods
  static Future<bool> _contactPerson(
    EmergencyContact contact,
    EmergencyAlert alert,
    String urgencyLevel,
  ) async {
    try {
      // Try preferred methods in order
      for (var method in contact.preferredContactMethods) {
        switch (method) {
          case 'call':
            final success = await _makePhoneCall(contact, alert, urgencyLevel);
            if (success) return true;
            break;
          case 'sms':
            final success = await _sendSMS(contact, alert, urgencyLevel);
            if (success) return true;
            break;
          case 'email':
            final success = await _sendEmail(contact, alert, urgencyLevel);
            if (success) return true;
            break;
        }
      }

      // Update last contacted
      await _firestore
          .collection('emergency_contacts')
          .doc(contact.id)
          .update({'lastContacted': FieldValue.serverTimestamp()});

      return true;
    } catch (e) {
      debugPrint('Error contacting ${contact.name}: $e');
      return false;
    }
  }

  /// Make phone call
  static Future<bool> _makePhoneCall(
    EmergencyContact contact,
    EmergencyAlert alert,
    String urgencyLevel,
  ) async {
    try {
      final Uri phoneUri = Uri(scheme: 'tel', path: contact.phoneNumber);

      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);

        // Haptic feedback for urgency
        if (urgencyLevel == 'CRITICAL_EMERGENCY') {
          await HapticFeedback.heavyImpact();
          await Future.delayed(const Duration(milliseconds: 100));
          await HapticFeedback.heavyImpact();
        } else {
          await HapticFeedback.mediumImpact();
        }

        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error making phone call: $e');
      return false;
    }
  }

  /// Send SMS message
  static Future<bool> _sendSMS(
    EmergencyContact contact,
    EmergencyAlert alert,
    String urgencyLevel,
  ) async {
    try {
      final message = _generateEmergencyMessage(contact, alert, urgencyLevel);
      final Uri smsUri = Uri(
        scheme: 'sms',
        path: contact.phoneNumber,
        queryParameters: {'body': message},
      );

      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error sending SMS: $e');
      return false;
    }
  }

  /// Send email
  static Future<bool> _sendEmail(
    EmergencyContact contact,
    EmergencyAlert alert,
    String urgencyLevel,
  ) async {
    if (contact.email == null) return false;

    try {
      final subject = '🚨 KinCircle Emergency Alert - ${alert.riskLevel.name.toUpperCase()}';
      final body = _generateEmergencyMessage(contact, alert, urgencyLevel);

      final Uri emailUri = Uri(
        scheme: 'mailto',
        path: contact.email,
        queryParameters: {
          'subject': subject,
          'body': body,
        },
      );

      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error sending email: $e');
      return false;
    }
  }

  /// Contact medical professional with specialized alert
  static Future<bool> _contactMedicalProfessional(
    EmergencyContact medical,
    EmergencyAlert alert,
  ) async {
    return await _contactPerson(medical, alert, 'MEDICAL_EMERGENCY');
  }

  /// Call 911
  static Future<bool> _call911(
    EmergencyContact emergency911,
    EmergencyAlert alert,
  ) async {
    try {
      final Uri phoneUri = Uri(scheme: 'tel', path: '911');

      if (await canLaunchUrl(phoneUri)) {
        // Prepare 911 information packet
        await _prepare911Info(alert);

        // Double haptic for maximum urgency
        await HapticFeedback.heavyImpact();
        await Future.delayed(const Duration(milliseconds: 100));
        await HapticFeedback.heavyImpact();

        await launchUrl(phoneUri);
        return true;
      }
      await _emergencyFallback(alert);
      return false;
    } catch (e) {
      debugPrint('Error calling 911: $e');
      await _emergencyFallback(alert);
      return false;
    }
  }

  /// Generate context-aware emergency message
  static String _generateEmergencyMessage(
    EmergencyContact contact,
    EmergencyAlert alert,
    String urgencyLevel,
  ) {
    final location =
        'https://maps.google.com/?q=${alert.currentLat},${alert.currentLng}';
    final timeEstimate = alert.estimatedTimeUntilDanger ?? 'UNKNOWN';

    switch (urgencyLevel) {
      case 'MEDIUM_RISK':
        return '''🔔 KINCIRCLE ALERT - Medium Risk

${contact.name}, we detected unusual movement patterns that may indicate wandering risk.

CURRENT LOCATION: $location
ESTIMATED TIME TO DANGER: $timeEstimate minutes

RECOMMENDED ACTIONS:
• Check on your family member
• Monitor location for next 15 minutes
• Consider gentle reminder call

Reply SAFE if they are with you.
Reply HELP if you need emergency assistance.''';

      case 'HIGH_RISK':
        return '''🚨 KINCIRCLE EMERGENCY - High Risk Wandering

${contact.name}, URGENT: High wandering risk detected. IMMEDIATE ACTION REQUIRED.

CURRENT LOCATION: $location
PREDICTED DIRECTION: ${alert.predictedDirection ?? 'Unknown'}°
TIME TO DANGER: $timeEstimate minutes

CRITICAL ACTIONS NEEDED:
• Contact family member immediately
• Activate GPS tracking
• Prepare to send help
• Check recent activity patterns

CONTACT THEM NOW: This is a serious safety risk.

Reply SAFE when located. Reply HELP for emergency assistance.''';

      case 'CRITICAL_EMERGENCY':
        return '''🚨🚨 CRITICAL EMERGENCY - WANDERING CRISIS

${contact.name}, EMERGENCY: Critical wandering situation detected.

IMMEDIATE LOCATION: $location
DANGER TIMELINE: $timeEstimate MINUTES

🆘 EMERGENCY ACTIONS:
• CALL THEM IMMEDIATELY
• GO TO LOCATION IF CLOSE
• CONTACT AUTHORITIES IF NO RESPONSE
• MEDICAL INFO: ${contact.medicalInfo ?? 'See family emergency plan'}

This is a life-threatening situation. Act NOW.

Reply FOUND when safe. Call 911 if needed.''';

      case 'MEDICAL_EMERGENCY':
        return '''🏥 MEDICAL EMERGENCY ALERT - Wandering Patient

Dr. ${contact.name}, urgent medical situation requiring your expertise.

PATIENT WANDERING CRISIS:
Location: ${alert.currentLat}, ${alert.currentLng}
Risk Level: ${alert.riskLevel.name.toUpperCase()}
Time Estimate: $timeEstimate minutes

MEDICAL CONSIDERATIONS:
${contact.medicalInfo ?? 'Patient medical history available in system'}

RISK FACTORS: ${alert.riskFactors.join(', ')}

Your immediate medical guidance requested for family response coordination.

Contact family coordinator or respond to this emergency.''';

      default:
        return 'KinCircle Emergency Alert: Please check on your family member.';
    }
  }

  /// Get emergency contacts for user
  static Future<List<EmergencyContact>> getEmergencyContacts(
    String userId, {
    FirebaseFirestore? firestore,
  }) async {
    final FirebaseFirestore db = firestore ?? _firestore;
    try {
      final snapshot = await db
          .collection('emergency_contacts')
          .where('userId', isEqualTo: userId)
          .where('isAvailable', isEqualTo: true)
          .get();

      final contacts = snapshot.docs
          .map((doc) => EmergencyContact.fromFirestore(doc.data()))
          .toList();

      // Sort by priority
      contacts.sort((a, b) => a.priority.compareTo(b.priority));

      return contacts;
    } catch (e) {
      debugPrint('Error loading emergency contacts: $e');
      return [];
    }
  }

  /// Helper methods - Production implementations
  static Future<void> _activateEnhancedTracking(String userId) async {
    // Activate enhanced tracking (30-second intervals)
    try {
      await _firestore.collection('users').doc(userId).update({
        'trackingMode': 'enhanced',
        'trackingIntervalSeconds': 30,
        'trackingActivatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('Enhanced tracking activated for $userId');
    } catch (e) {
      debugPrint('Error activating enhanced tracking: $e');
    }
  }

  static Future<void> _sendLocationToContacts(
    List<EmergencyContact> contacts,
    EmergencyAlert alert,
  ) async {
    // Send real-time location updates to emergency contacts
    final locationData = {
      'lat': alert.currentLat,
      'lng': alert.currentLng,
      'timestamp': FieldValue.serverTimestamp(),
      'riskLevel': alert.riskLevel.name,
    };
    
    for (final contact in contacts) {
      try {
        // Store location share in Firestore for contacts to access
        await _firestore.collection('emergency_location_shares').add({
          'contactId': contact.id,
          'contactPhone': contact.phoneNumber,
          'location': locationData,
          'expiresAt': DateTime.now().add(const Duration(hours: 24)).toIso8601String(),
        });
      } catch (e) {
        debugPrint('Error sending location to ${contact.name}: $e');
      }
    }
  }

  static Future<void> _activateLiveLocationSharing(
    String userId,
    EmergencyAlert alert,
  ) async {
    // Enable live location streaming to family members
    try {
      await _firestore.collection('users').doc(userId).update({
        'liveLocationSharing': true,
        'liveLocationStartedAt': FieldValue.serverTimestamp(),
        'emergencyLocation': GeoPoint(alert.currentLat, alert.currentLng),
      });
      debugPrint('Live location sharing activated for $userId');
    } catch (e) {
      debugPrint('Error activating live location sharing: $e');
    }
  }

  static Future<void> _activateEmergencyBeacon(
    String userId,
    EmergencyAlert alert,
  ) async {
    // Activate emergency beacon mode (max frequency, all features)
    try {
      await _firestore.collection('users').doc(userId).update({
        'emergencyBeacon': true,
        'trackingMode': 'beacon',
        'trackingIntervalSeconds': 5, // Maximum frequency
        'beaconActivatedAt': FieldValue.serverTimestamp(),
        'emergencyLocation': GeoPoint(alert.currentLat, alert.currentLng),
        'riskLevel': alert.riskLevel.name,
      });
      
      // Also create a public beacon record for responders
      await _firestore.collection('emergency_beacons').add({
        'userId': userId,
        'location': GeoPoint(alert.currentLat, alert.currentLng),
        'activatedAt': FieldValue.serverTimestamp(),
        'riskLevel': alert.riskLevel.name,
        'active': true,
      });
      
      debugPrint('Emergency beacon activated for $userId');
    } catch (e) {
      debugPrint('Error activating emergency beacon: $e');
    }
  }

  static Future<void> _broadcastMedicalInfo(
    List<EmergencyContact> contacts,
    EmergencyAlert alert,
  ) async {
    // Broadcast medical information to emergency responders
    final medicalContacts = contacts.where(
      (c) => c.type == EmergencyContactType.medicalProfessional || 
             c.type == EmergencyContactType.emergency911
    ).toList();
    
    for (final contact in medicalContacts) {
      try {
        await _firestore.collection('medical_broadcasts').add({
          'contactId': contact.id,
          'contactType': contact.type.name,
          'location': GeoPoint(alert.currentLat, alert.currentLng),
          'riskLevel': alert.riskLevel.name,
          'riskFactors': alert.riskFactors,
          'broadcastedAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        debugPrint('Error broadcasting medical info to ${contact.name}: $e');
      }
    }
  }

  static Future<void> _createEmergencyChat(
    String responseId,
    List<EmergencyContact> contacts,
  ) async {
    // Create emergency coordination chat/channel
    try {
      final memberIds = contacts.map((c) => c.id).toList();
      
      await _firestore.collection('emergency_chats').doc(responseId).set({
        'responseId': responseId,
        'members': memberIds,
        'createdAt': FieldValue.serverTimestamp(),
        'active': true,
        'messages': [],
      });
      
      // Add initial system message
      await _firestore.collection('emergency_chats').doc(responseId)
          .collection('messages').add({
        'type': 'system',
        'text': 'Emergency coordination channel created. All contacts notified.',
        'timestamp': FieldValue.serverTimestamp(),
      });
      
      debugPrint('Emergency chat created: $responseId');
    } catch (e) {
      debugPrint('Error creating emergency chat: $e');
    }
  }

  static Future<void> _prepare911Info(EmergencyAlert alert) async {
    // Prepare comprehensive information packet for 911 dispatcher
    // This data can be read by dispatch if available
    try {
      await _firestore.collection('911_info_packets').add({
        'location': GeoPoint(alert.currentLat, alert.currentLng),
        'riskLevel': alert.riskLevel.name,
        'riskFactors': alert.riskFactors,
        'estimatedTimeUntilDanger': alert.estimatedTimeUntilDanger,
        'predictedDirection': alert.predictedDirection,
        'createdAt': FieldValue.serverTimestamp(),
        'mapUrl': 'https://maps.google.com/?q=${alert.currentLat},${alert.currentLng}',
      });
    } catch (e) {
      debugPrint('Error preparing 911 info: $e');
    }
  }

  static void _scheduleEscalation(String responseId, Duration delay) {
    Future<void>.delayed(delay, () async {
      try {
        await _escalateResponse(responseId);
      } catch (e) {
        debugPrint('Error escalating response $responseId: $e');
      }
    });
  }

  static Future<void> _escalateResponse(String responseId) async {
    try {
      await _firestore.collection('emergency_responses').doc(responseId).set(
        {
          'status': EmergencyResponseStatus.escalated.name,
          'notes': 'Auto-escalated after timeout',
          'resolvedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('Error persisting escalation for $responseId: $e');
    }
  }

  static Future<void> _emergencyFallback(EmergencyAlert alert) async {
    // Last resort: Direct 911 call if all systems fail
    try {
      final Uri phoneUri = Uri(scheme: 'tel', path: '911');
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      }
    } catch (e) {
      debugPrint('Error in emergency fallback: $e');
    }
  }
}
