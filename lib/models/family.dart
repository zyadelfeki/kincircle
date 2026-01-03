class Family {
  Family({
    required this.id,
    required this.name,
    required this.members,
    this.ownerId,
    this.createdAt,
  });

  /// Factory constructor to create Family from Firestore data
  factory Family.fromMap(String id, Map<String, dynamic> data) {
    return Family(
      id: id,
      name: data['name'] ?? 'Family',
      members: List<String>.from(data['members'] ?? []),
      ownerId: data['ownerId'],
      createdAt: data['createdAt']?.toDate(),
    );
  }

  final String id;
  final String name;
  final List<String> members;
  final String? ownerId;
  final DateTime? createdAt;

  /// Check if the given userId is the owner of this family
  bool isOwner(String currentUserId) {
    return ownerId == currentUserId;
  }

  /// Convert Family to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'members': members,
      'ownerId': ownerId,
      'createdAt': createdAt,
    };
  }

  /// Create a copy of this Family with some fields replaced
  Family copyWith({
    String? id,
    String? name,
    List<String>? members,
    String? ownerId,
    DateTime? createdAt,
  }) {
    return Family(
      id: id ?? this.id,
      name: name ?? this.name,
      members: members ?? this.members,
      ownerId: ownerId ?? this.ownerId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class FamilyMember {
  FamilyMember({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.isOwner,
  });

  factory FamilyMember.fromMap(Map<String, dynamic> data) {
    return FamilyMember(
      uid: data['uid'],
      email: data['email'] ?? '',
      displayName: data['displayName'] ?? data['email'] ?? 'Unknown User',
      isOwner: data['isOwner'] ?? false,
    );
  }

  final String uid;
  final String email;
  final String displayName;
  final bool isOwner;

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'isOwner': isOwner,
    };
  }
}
