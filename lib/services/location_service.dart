import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class LocationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool? _canShareLocationCache;
  DateTime? _canShareLocationCacheAt;
  static const Duration _locationShareCacheTtl = Duration(seconds: 20);

  Future<bool> requestPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  Stream<Position> startLocationUpdates() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Update every 10 meters
      ),
    );
  }

  Future<void> updateUserLocation(Position position) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final bool canShare = await _canShareLocation(user.uid);
      if (!canShare) return;

      await _firestore.collection('users').doc(user.uid).update({
        'lastKnownLocation': GeoPoint(position.latitude, position.longitude),
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      // Log Firebase-specific errors with context
      debugPrint('Firebase error updating location: ${e.code} - ${e.message}');
      // Retry logic for transient failures
      if (e.code == 'unavailable' || e.code == 'deadline-exceeded') {
        await Future.delayed(const Duration(seconds: 2));
        try {
          await _firestore.collection('users').doc(user.uid).update({
            'lastKnownLocation': GeoPoint(position.latitude, position.longitude),
            'lastUpdated': FieldValue.serverTimestamp(),
          });
        } catch (_) {
          // Silent fail on retry - location will update on next position change
        }
      }
    } catch (e) {
      debugPrint('Error updating location: $e');
    }
  }

  Future<bool> _canShareLocation(String uid) async {
    final DateTime now = DateTime.now();
    final DateTime? cachedAt = _canShareLocationCacheAt;
    if (_canShareLocationCache != null &&
        cachedAt != null &&
        now.difference(cachedAt) < _locationShareCacheTtl) {
      return _canShareLocationCache!;
    }

    final DocumentSnapshot<Map<String, dynamic>> userDoc =
        await _firestore.collection('users').doc(uid).get();
    final bool invisibleMode = userDoc.data()?['invisibleMode'] as bool? ?? false;
    final bool canShare = !invisibleMode;
    _canShareLocationCache = canShare;
    _canShareLocationCacheAt = now;
    return canShare;
  }

  Future<Position?> getCurrentLocation() async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
    } catch (e) {
      debugPrint('Error getting location: $e');
      return null;
    }
  }
}
