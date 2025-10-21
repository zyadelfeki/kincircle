import 'package:cloud_firestore/cloud_firestore.dart';

/// Emergency contact types for hierarchical response
enum EmergencyContactType {
  primaryFamily,
  secondaryFamily,
  caregiver,
  medicalProfessional,
  neighbor,
  emergency911,
  friend,
}

/// Emergency response status tracking
enum EmergencyResponseStatus {
  active,
  resolved,
  escalated,
  cancelled,
}

/// Emergency actions that can be taken
enum EmergencyAction {
  contactPrimary,
  contactSecondary,
  notifyCaregiver,
  callMedical,
  call911,
  sendLocation,
  activateTracking,
  notifyNeighbors,
}

/// Emergency contact model for crisis coordination
class EmergencyContact {
  final String id;
  final String name;
  final String phoneNumber;
  final String? email;
  final EmergencyContactType type;
  final int priority; // 1 = highest priority
  final bool isAvailable;
  final String? specialInstructions;
  final DateTime? lastContacted;
  final List<String> preferredContactMethods; // ['call', 'sms', 'email']
  final String? medicalInfo;

  EmergencyContact({
    required this.id,
    required this.name,
    required this.phoneNumber,
    this.email,
    required this.type,
    required this.priority,
    this.isAvailable = true,
    this.specialInstructions,
    this.lastContacted,
    this.preferredContactMethods = const ['call', 'sms'],
    this.medicalInfo,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'name': name,
      'phoneNumber': phoneNumber,
      'email': email,
      'type': type.name,
      'priority': priority,
      'isAvailable': isAvailable,
      'specialInstructions': specialInstructions,
      'lastContacted': lastContacted,
      'preferredContactMethods': preferredContactMethods,
      'medicalInfo': medicalInfo,
    };
  }

  factory EmergencyContact.fromFirestore(Map<String, dynamic> data) {
    return EmergencyContact(
      id: data['id'] as String,
      name: data['name'] as String,
      phoneNumber: data['phoneNumber'] as String,
      email: data['email'] as String?,
      type: EmergencyContactType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => EmergencyContactType.friend,
      ),
      priority: data['priority'] as int,
      isAvailable: data['isAvailable'] as bool? ?? true,
      specialInstructions: data['specialInstructions'] as String?,
      lastContacted: data['lastContacted'] != null
          ? (data['lastContacted'] as Timestamp).toDate()
          : null,
      preferredContactMethods: (data['preferredContactMethods'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          ['call', 'sms'],
      medicalInfo: data['medicalInfo'] as String?,
    );
  }
}

/// Emergency response tracking model
class EmergencyResponse {
  final String responseId;
  final String userId;
  final DateTime triggeredAt;
  final String riskLevel;
  final double currentLat;
  final double currentLng;
  final List<String> contactedPersons;
  final List<String> actionsCompleted;
  final EmergencyResponseStatus status;
  final String? resolvedBy;
  final DateTime? resolvedAt;
  final String? notes;

  EmergencyResponse({
    required this.responseId,
    required this.userId,
    required this.triggeredAt,
    required this.riskLevel,
    required this.currentLat,
    required this.currentLng,
    this.contactedPersons = const [],
    this.actionsCompleted = const [],
    this.status = EmergencyResponseStatus.active,
    this.resolvedBy,
    this.resolvedAt,
    this.notes,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'responseId': responseId,
      'userId': userId,
      'triggeredAt': Timestamp.fromDate(triggeredAt),
      'riskLevel': riskLevel,
      'currentLat': currentLat,
      'currentLng': currentLng,
      'contactedPersons': contactedPersons,
      'actionsCompleted': actionsCompleted,
      'status': status.name,
      'resolvedBy': resolvedBy,
      'resolvedAt': resolvedAt != null ? Timestamp.fromDate(resolvedAt!) : null,
      'notes': notes,
    };
  }
}
