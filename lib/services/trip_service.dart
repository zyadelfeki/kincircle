import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/trip.dart';
import 'package:flutter/foundation.dart';

class TripService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get all trips for the current user
  Stream<List<Trip>> getUserTrips() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('trips')
        .where('userId', isEqualTo: user.uid)
        .orderBy('startTime', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return Trip.fromMap(doc.id, doc.data());
      }).toList();
    });
  }

  /// Get trips for a specific family (for family members to see each other's trips)
  Stream<List<Trip>> getFamilyTrips(String familyId) {
    return _firestore
        .collection('trips')
        .where('familyId', isEqualTo: familyId)
        .orderBy('startTime', descending: true)
        .limit(50) // Limit to recent trips for performance
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return Trip.fromMap(doc.id, doc.data());
      }).toList();
    });
  }

  /// Get a specific trip by ID
  Future<Trip?> getTripById(String tripId) async {
    try {
      final doc = await _firestore.collection('trips').doc(tripId).get();
      if (doc.exists) {
        return Trip.fromMap(doc.id, doc.data()!);
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error getting trip: $e');
      }
      return null;
    }
  }

  /// Get trip statistics for the current user
  Future<Map<String, dynamic>> getUserTripStats({int? lastNDays}) async {
    final user = _auth.currentUser;
    if (user == null) {
      return {
        'totalTrips': 0,
        'totalDistance': 0.0,
        'totalDuration': 0.0,
        'averageDistance': 0.0,
        'averageDuration': 0.0,
      };
    }

    Query query = _firestore
        .collection('trips')
        .where('userId', isEqualTo: user.uid);

    // Add date filter if specified
    if (lastNDays != null) {
      final cutoffDate = DateTime.now().subtract(Duration(days: lastNDays));
      query = query.where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(cutoffDate));
    }

    try {
      final snapshot = await query.get();
      final trips = snapshot.docs.map((doc) => Trip.fromMap(doc.id, doc.data() as Map<String, dynamic>)).toList();

      if (trips.isEmpty) {
        return {
          'totalTrips': 0,
          'totalDistance': 0.0,
          'totalDuration': 0.0,
          'averageDistance': 0.0,
          'averageDuration': 0.0,
        };
      }

  final totalDistance = trips.fold<double>(0, (total, trip) => total + trip.distanceKm);
  final totalDuration = trips.fold<double>(0, (total, trip) => total + trip.durationMinutes);

      return {
        'totalTrips': trips.length,
        'totalDistance': totalDistance,
        'totalDuration': totalDuration,
        'averageDistance': totalDistance / trips.length,
        'averageDuration': totalDuration / trips.length,
      };
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error getting trip stats: $e');
      }
      return {
        'totalTrips': 0,
        'totalDistance': 0.0,
        'totalDuration': 0.0,
        'averageDistance': 0.0,
        'averageDuration': 0.0,
      };
    }
  }

  /// Get recent trips (last 7 days) for quick access
  Future<List<Trip>> getRecentTrips() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    try {
      final cutoffDate = DateTime.now().subtract(const Duration(days: 7));
      final snapshot = await _firestore
          .collection('trips')
          .where('userId', isEqualTo: user.uid)
          .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(cutoffDate))
          .orderBy('startTime', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        return Trip.fromMap(doc.id, doc.data());
      }).toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error getting recent trips: $e');
      }
      return [];
    }
  }

  /// Delete a trip (admin function, generally not used by clients)
  Future<bool> deleteTrip(String tripId) async {
    try {
      await _firestore.collection('trips').doc(tripId).delete();
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error deleting trip: $e');
      }
      return false;
    }
  }

  /// Get trips grouped by date for the current user
  Future<Map<String, List<Trip>>> getTripsGroupedByDate({int? lastNDays}) async {
    final user = _auth.currentUser;
    if (user == null) return {};

    Query query = _firestore
        .collection('trips')
        .where('userId', isEqualTo: user.uid)
        .orderBy('startTime', descending: true);

    if (lastNDays != null) {
      final cutoffDate = DateTime.now().subtract(Duration(days: lastNDays));
      query = query.where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(cutoffDate));
    }

    try {
      final snapshot = await query.get();
      final trips = snapshot.docs.map((doc) => Trip.fromMap(doc.id, doc.data() as Map<String, dynamic>)).toList();

      final groupedTrips = <String, List<Trip>>{};
      
      for (final trip in trips) {
        final dateKey = '${trip.startTime.year}-${trip.startTime.month.toString().padLeft(2, '0')}-${trip.startTime.day.toString().padLeft(2, '0')}';
        
        if (!groupedTrips.containsKey(dateKey)) {
          groupedTrips[dateKey] = [];
        }
        groupedTrips[dateKey]!.add(trip);
      }

      return groupedTrips;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error getting grouped trips: $e');
      }
      return {};
    }
  }

  /// Create a test trip for development/testing purposes
  Future<void> createTestTrip() async {
    final user = _auth.currentUser;
    if (user == null) throw 'User not authenticated';

    // Get user's family ID
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final familyId = userDoc.data()?['currentFamilyId'];

    // Create a sample trip with realistic data
    final now = DateTime.now();
    final startTime = now.subtract(const Duration(minutes: 25));
    final endTime = now.subtract(const Duration(minutes: 5));
    final durationMinutes = endTime.difference(startTime).inMinutes.toDouble();

    final testTrip = Trip(
      id: '', // Will be set by Firestore
      userId: user.uid,
      familyId: familyId ?? '',
      startTime: startTime,
      endTime: endTime,
      durationMinutes: durationMinutes,
      distanceKm: 8.5,
      startAddress: '123 Test Start St, New York, NY',
      endAddress: '456 Test End Ave, New York, NY',
      routePath: [
        // Sample route points for visualization using GeoPoint
        const GeoPoint(40.7128, -74.0060),
        const GeoPoint(40.7200, -74.0000),
        const GeoPoint(40.7300, -73.9950),
        const GeoPoint(40.7400, -73.9900),
        const GeoPoint(40.7500, -73.9860),
        const GeoPoint(40.7589, -73.9851),
      ],
    );

    await _firestore.collection('trips').add(testTrip.toMap());
  }
}
