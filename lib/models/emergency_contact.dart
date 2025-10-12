import 'package:cloud_firestore/cloud_firestore.dart';

/// Types of emergency contacts in the hierarchy
enum EmergencyContactType {
  family,
  medical,
  firstResponder,
}

/// Priority level for contact notification order
enum EmergencyContactPriority {
  primary,
  secondary,
  tertiary,
}

/// Represents an emergency contact with notification preferences
class EmergencyContact {
  final String id;
  final String userId;
  final String name;
  final String phoneNumber;
  final String? email;
  final EmergencyContactType type;
  final EmergencyContactPriority priority;
  final bool notifyByPhone;
  final bool notifyByEmail;
  final bool notifyBySms;
  final DateTime createdAt;
  final DateTime updatedAt;

  EmergencyContact({
    required this.id,
    required this.userId,
    required this.name,
    required this.phoneNumber,
    this.email,
    required this.type,
    required this.priority,
    this.notifyByPhone = true,
    this.notifyByEmail = false,
    this.notifyBySms = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory EmergencyContact.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return EmergencyContact(
      id: doc.id,
      userId: data['userId'] as String,
      name: data['name'] as String,
      phoneNumber: data['phoneNumber'] as String,
      email: data['email'] as String?,
      type: EmergencyContactType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => EmergencyContactType.family,
      ),
      priority: EmergencyContactPriority.values.firstWhere(
        (e) => e.name == data['priority'],
        orElse: () => EmergencyContactPriority.secondary,
      ),
      notifyByPhone: data['notifyByPhone'] as bool? ?? true,
      notifyByEmail: data['notifyByEmail'] as bool? ?? false,
      notifyBySms: data['notifyBySms'] as bool? ?? true,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'name': name,
      'phoneNumber': phoneNumber,
      'email': email,
      'type': type.name,
      'priority': priority.name,
      'notifyByPhone': notifyByPhone,
      'notifyByEmail': notifyByEmail,
      'notifyBySms': notifyBySms,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  EmergencyContact copyWith({
    String? id,
    String? userId,
    String? name,
    String? phoneNumber,
    String? email,
    EmergencyContactType? type,
    EmergencyContactPriority? priority,
    bool? notifyByPhone,
    bool? notifyByEmail,
    bool? notifyBySms,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return EmergencyContact(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      type: type ?? this.type,
      priority: priority ?? this.priority,
      notifyByPhone: notifyByPhone ?? this.notifyByPhone,
      notifyByEmail: notifyByEmail ?? this.notifyByEmail,
      notifyBySms: notifyBySms ?? this.notifyBySms,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
