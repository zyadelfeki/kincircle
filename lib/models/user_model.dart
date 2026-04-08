import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class AppUser {
  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    LatLng? location;
    if (data['lastKnownLocation'] != null) {
      final geoPoint = data['lastKnownLocation'] as GeoPoint;
      location = LatLng(geoPoint.latitude, geoPoint.longitude);
    }

    final String rawDisplayName = (data['displayName'] ?? '').toString().trim();
    final String email = (data['email'] ?? '').toString().trim();
    String resolvedDisplayName = rawDisplayName;
    if (resolvedDisplayName.isEmpty) {
      if (email.contains('@')) {
        resolvedDisplayName = email.split('@').first.trim();
      }
      if (resolvedDisplayName.isEmpty) {
        resolvedDisplayName = 'Unknown';
      }
    }

    return AppUser(
      uid: doc.id,
      displayName: resolvedDisplayName,
      photoURL: data['photoURL'] ?? '',
      isInvisible: data['invisibleMode'] ?? false,
      lastKnownLocation: location,
      lastUpdated: (data['lastUpdated'] as Timestamp?)?.toDate(),
      currentFamilyId: data['currentFamilyId'],
    );
  }

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      uid: map['uid'] ?? '',
      displayName: map['displayName'] ?? '',
      photoURL: map['photoURL'] ?? '',
      isInvisible: map['invisibleMode'] ?? false,
      lastKnownLocation: map['lastKnownLocation'] != null
          ? LatLng(map['lastKnownLocation']['latitude'],
              map['lastKnownLocation']['longitude'])
          : null,
      lastUpdated: map['lastUpdated'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['lastUpdated'])
          : null,
      currentFamilyId: map['currentFamilyId'],
    );
  }

  AppUser({
    required this.uid,
    required this.displayName,
    required this.photoURL,
    required this.isInvisible,
    this.lastKnownLocation,
    this.lastUpdated,
    this.currentFamilyId,
  });

  final String uid;
  final String displayName;
  final String photoURL;
  final LatLng? lastKnownLocation;
  final DateTime? lastUpdated;
  final bool isInvisible;
  final String? currentFamilyId;

  // Create a copy of AppUser with some fields updated
  AppUser copyWith({
    String? uid,
    String? displayName,
    String? photoURL,
    LatLng? lastKnownLocation,
    DateTime? lastUpdated,
    bool? isInvisible,
    String? currentFamilyId,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      displayName: displayName ?? this.displayName,
      photoURL: photoURL ?? this.photoURL,
      isInvisible: isInvisible ?? this.isInvisible,
      lastKnownLocation: lastKnownLocation ?? this.lastKnownLocation,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      currentFamilyId: currentFamilyId ?? this.currentFamilyId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'displayName': displayName,
      'photoURL': photoURL,
      'invisibleMode': isInvisible,
      'currentFamilyId': currentFamilyId,
      if (lastKnownLocation != null)
        'lastKnownLocation': GeoPoint(
          lastKnownLocation!.latitude,
          lastKnownLocation!.longitude,
        ),
      'lastUpdated':
          lastUpdated != null ? Timestamp.fromDate(lastUpdated!) : null,
    };
  }
}
