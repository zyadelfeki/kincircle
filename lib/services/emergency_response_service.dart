import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/emergency_contact.dart';

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
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Main entry point: Trigger emergency response based on emergency alert
  static Future<EmergencyResponse> triggerEmergencyResponse({
    required String userId,
    required EmergencyAlert alert,
  }) async {
    // Create response record
    final response = EmergencyResponse(
      responseId: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: userId,
      triggeredAt: DateTime.now(),
      riskLevel: alert.riskLevel.name,
      currentLat: alert.currentLat,
      currentLng: alert.currentLng,
    );

    // Store in Firestore
    await _firestore
        .collection('emergency_responses')
        .doc(response.responseId)
        .set(response.toFirestore());

    // Get emergency contacts
    final contacts = await getEmergencyContacts(userId);

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
      print('Error contacting ${contact.name}: $e');
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
      print('Error making phone call: $e');
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
      print('Error sending SMS: $e');
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
      print('Error sending email: $e');
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
      return false;
    } catch (e) {
      print('Error calling 911: $e');
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
      String userId) async {
    try {
      final snapshot = await _firestore
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
      print('Error loading emergency contacts: $e');
      return [];
    }
  }

  /// Helper methods (placeholders for full implementation)
  static Future<void> _activateEnhancedTracking(String userId) async {
    // TODO: Increase location tracking frequency to 30 seconds
  }

  static Future<void> _sendLocationToContacts(
    List<EmergencyContact> contacts,
    EmergencyAlert alert,
  ) async {
    // TODO: Send real-time location updates
  }

  static Future<void> _activateLiveLocationSharing(
    String userId,
    EmergencyAlert alert,
  ) async {
    // TODO: Enable live location streaming
  }

  static Future<void> _activateEmergencyBeacon(
    String userId,
    EmergencyAlert alert,
  ) async {
    // TODO: Maximum frequency tracking + beacon mode
  }

  static Future<void> _broadcastMedicalInfo(
    List<EmergencyContact> contacts,
    EmergencyAlert alert,
  ) async {
    // TODO: Send medical information to responders
  }

  static Future<void> _createEmergencyChat(
    String responseId,
    List<EmergencyContact> contacts,
  ) async {
    // TODO: Create group chat for coordination
  }

  static Future<void> _prepare911Info(EmergencyAlert alert) async {
    // TODO: Prepare information packet for 911 dispatcher
  }

  static void _scheduleEscalation(String responseId, Duration delay) {
    // TODO: Implement escalation timer with auto-escalation
  }

  static Future<void> _escalateResponse(String responseId) async {
    // TODO: Escalate response to next level
  }

  static Future<void> _emergencyFallback(EmergencyAlert alert) async {
    // Last resort: Direct 911 call if all systems fail
    final Uri phoneUri = Uri(scheme: 'tel', path: '911');
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    }
  }
}
