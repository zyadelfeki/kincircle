import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:permission_handler/permission_handler.dart';
import 'trip_detection_service.dart';
import 'geofence_monitor_service.dart';

/// Manages the lifecycle of TripDetectionService based on user authentication state
class TripServiceManager {
  factory TripServiceManager() => _instance;
  TripServiceManager._internal();
  static final TripServiceManager _instance = TripServiceManager._internal();

  TripDetectionService? _tripDetectionService;
  StreamSubscription<User?>? _authSubscription;
  bool _isInitialized = false;

  /// Initialize the service manager - should be called once at app startup
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // Listen to authentication state changes
      _authSubscription = FirebaseAuth.instance.authStateChanges().listen(
        _onAuthStateChanged,
        onError: (error) {
          if (kDebugMode) {
            debugPrint('TripServiceManager: Auth state error: $error');
          }
        },
      );
      
      _isInitialized = true;
      if (kDebugMode) {
        debugPrint('TripServiceManager: Initialized successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('TripServiceManager: Failed to initialize: $e');
      }
    }
  }

  /// Handle authentication state changes
  void _onAuthStateChanged(User? user) async {
    if (kDebugMode) {
      debugPrint('TripServiceManager: Auth state changed - User: ${user?.uid}');
    }
    
    if (user != null) {
      // User logged in - start trip detection service & geofence monitor
      GeofenceMonitorService().startMonitoring();
      await _startTripDetection();
    } else {
      // User logged out - stop trip detection service & geofence monitor
      GeofenceMonitorService().cancel();
      await _stopTripDetection();
    }
  }

  /// Start the trip detection service
  Future<void> _startTripDetection() async {
    if (_tripDetectionService != null) {
      if (kDebugMode) {
        debugPrint('TripServiceManager: Trip detection already running');
      }
      return;
    }

    try {
      // Check location permissions first
      final locationPermission = await Permission.locationWhenInUse.status;
      if (!locationPermission.isGranted) {
        if (kDebugMode) {
          debugPrint('TripServiceManager: Location permission not granted, cannot start trip detection');
        }
        return;
      }

      final status = await Permission.activityRecognition.request();
      if (!status.isGranted) return;

      // Create and initialize the service
      _tripDetectionService = TripDetectionService();
      await _tripDetectionService!.initialize();
      
      if (kDebugMode) {
        debugPrint('TripServiceManager: Trip detection service started');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('TripServiceManager: Failed to start trip detection: $e');
      }
      _tripDetectionService = null;
    }
  }

  /// Stop the trip detection service
  Future<void> _stopTripDetection() async {
    if (_tripDetectionService == null) {
      if (kDebugMode) {
        debugPrint('TripServiceManager: Trip detection not running');
      }
      return;
    }

    try {
      await _tripDetectionService!.stop();
      _tripDetectionService = null;
      if (kDebugMode) {
        debugPrint('TripServiceManager: Trip detection service stopped');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('TripServiceManager: Error stopping trip detection: $e');
      }
    }
  }

  /// Get the current trip detection service instance
  TripDetectionService? get tripDetectionService => _tripDetectionService;

  /// Check if trip detection is currently active
  bool get isActive => _tripDetectionService != null;

  /// Dispose of the service manager
  Future<void> dispose() async {
    await _authSubscription?.cancel();
    await _stopTripDetection();
    _isInitialized = false;
    if (kDebugMode) {
      debugPrint('TripServiceManager: Disposed');
    }
  }
}