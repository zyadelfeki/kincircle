# Emergency Response System - Usage Guide

## Quick Start

### 1. Navigate to Emergency Contacts

From the app's main menu or dashboard, navigate to:
```dart
Navigator.of(context).pushNamed('/emergency-contacts');
```

### 2. Add Your First Emergency Contact

Tap the "+" button in the app bar and fill in:
- **Name**: John Smith
- **Phone**: +1-555-0100
- **Email**: john.smith@example.com (optional)
- **Type**: Family
- **Priority**: Primary
- **Notification Methods**: Check Phone and SMS

### 3. Add Additional Contacts

Follow the hierarchy:
1. **Primary Family**: Immediate family members who should be notified first
2. **Secondary Family**: Extended family or close friends
3. **Medical Professionals**: Doctors, therapists, caregivers
4. **First Responders**: Emergency contacts for critical situations

## Integration Examples

### Example 1: Manual Emergency Trigger

Create a panic button in your app:

```dart
import 'package:kincircle/services/emergency_response_service.dart';

class PanicButton extends StatelessWidget {
  final _emergencyService = EmergencyResponseService();

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.red,
        minimumSize: Size(200, 80),
      ),
      onPressed: () async {
        await _showEmergencyConfirmation(context);
      },
      child: Text('EMERGENCY', style: TextStyle(fontSize: 24)),
    );
  }

  Future<void> _showEmergencyConfirmation(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Trigger Emergency Response?'),
        content: Text('This will notify your emergency contacts immediately.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _triggerEmergency(context);
    }
  }

  Future<void> _triggerEmergency(BuildContext context) async {
    try {
      final results = await _emergencyService.triggerEmergencyResponse(
        riskLevel: EmergencyRiskLevel.high,
        reason: 'Manual emergency trigger - user activated panic button',
        metadata: {
          'source': 'panic_button',
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      final successCount = results.where((r) => r.success).length;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Emergency alert sent to $successCount contacts'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send emergency alert: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
```

### Example 2: Automatic Wandering Detection

Integrate with your location tracking service:

```dart
import 'package:geolocator/geolocator.dart';
import 'package:kincircle/services/wandering_prediction_service.dart';

class LocationMonitor {
  final _wanderingService = WanderingPredictionService();
  Position? _lastKnownPosition;
  DateTime? _lastLocationTime;
  final List<Position> _recentPositions = [];

  Future<void> onLocationUpdate(Position position) async {
    // Add to recent positions (keep last 10)
    _recentPositions.add(position);
    if (_recentPositions.length > 10) {
      _recentPositions.removeAt(0);
    }

    // Check for wandering risk
    await _wanderingService.monitorAndRespond(
      currentPosition: position,
      lastKnownPosition: _lastKnownPosition,
      lastLocationTime: _lastLocationTime,
      recentPositions: _recentPositions,
    );

    // Update tracking variables
    _lastKnownPosition = position;
    _lastLocationTime = DateTime.now();
  }
}
```

### Example 3: Geofence Exit Alert

Trigger emergency response when user leaves a safe zone:

```dart
import 'package:kincircle/services/emergency_response_service.dart';

class GeofenceMonitor {
  final _emergencyService = EmergencyResponseService();

  Future<void> onGeofenceExit(String geofenceName, Position position) async {
    // Trigger medium risk alert for geofence exit
    await _emergencyService.triggerEmergencyResponse(
      riskLevel: EmergencyRiskLevel.medium,
      reason: 'Left safe zone: $geofenceName',
      metadata: {
        'source': 'geofence_exit',
        'geofence_name': geofenceName,
        'location': {
          'latitude': position.latitude,
          'longitude': position.longitude,
        },
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }
}
```

### Example 4: Scheduled Check-In System

Automatically trigger alert if user doesn't check in:

```dart
import 'dart:async';
import 'package:kincircle/services/emergency_response_service.dart';

class CheckInService {
  final _emergencyService = EmergencyResponseService();
  Timer? _checkInTimer;
  DateTime? _lastCheckIn;

  void startMonitoring({Duration checkInInterval = const Duration(hours: 2)}) {
    _lastCheckIn = DateTime.now();
    
    _checkInTimer = Timer.periodic(checkInInterval, (timer) {
      _checkMissedCheckIn();
    });
  }

  void userCheckIn() {
    _lastCheckIn = DateTime.now();
    print('Check-in recorded at ${_lastCheckIn}');
  }

  Future<void> _checkMissedCheckIn() async {
    if (_lastCheckIn == null) return;

    final timeSinceCheckIn = DateTime.now().difference(_lastCheckIn!);
    
    if (timeSinceCheckIn.inHours >= 3) {
      await _emergencyService.triggerEmergencyResponse(
        riskLevel: EmergencyRiskLevel.medium,
        reason: 'Missed check-in: ${timeSinceCheckIn.inHours} hours without contact',
        metadata: {
          'source': 'check_in_system',
          'last_check_in': _lastCheckIn!.toIso8601String(),
          'hours_since_check_in': timeSinceCheckIn.inHours,
        },
      );
    }
  }

  void stopMonitoring() {
    _checkInTimer?.cancel();
  }
}
```

### Example 5: Display Emergency Contacts in Settings

Add emergency contacts to your settings screen:

```dart
import 'package:flutter/material.dart';
import 'package:kincircle/services/emergency_response_service.dart';
import 'package:kincircle/models/emergency_contact.dart';

class EmergencyContactWidget extends StatelessWidget {
  final _emergencyService = EmergencyResponseService();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: Icon(Icons.emergency, color: Colors.red),
            title: Text('Emergency Contacts'),
            subtitle: StreamBuilder<List<EmergencyContact>>(
              stream: _emergencyService.getEmergencyContacts(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return Text('Loading...');
                final count = snapshot.data!.length;
                return Text('$count contacts configured');
              },
            ),
            trailing: Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).pushNamed('/emergency-contacts');
            },
          ),
        ],
      ),
    );
  }
}
```

## Risk Level Guidelines

### When to Use Each Risk Level

#### Medium Risk (EmergencyRiskLevel.medium)
- User left safe geofence
- Missed scheduled check-in
- Minor deviation from routine
- First responder: Primary family only

#### High Risk (EmergencyRiskLevel.high)
- Significant distance from safe location
- No location update for >30 minutes
- Erratic movement patterns
- First responders: Family + Medical

#### Critical Risk (EmergencyRiskLevel.critical)
- Multiple risk factors combined
- User activated panic button
- Severe medical alert detected
- First responders: Full cascade (All contacts)

## Testing

### Test with Mock Contacts

For development, use test mode contacts:

```dart
// Add test contacts
await _emergencyService.addEmergencyContact(
  EmergencyContact(
    id: '',
    userId: '',
    name: 'Test Contact (Dev)',
    phoneNumber: '+1-555-TEST',
    email: 'test@example.com',
    type: EmergencyContactType.family,
    priority: EmergencyContactPriority.primary,
    notifyByPhone: false, // Disable actual notifications in dev
    notifyByEmail: false,
    notifyBySms: false,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  ),
);
```

### Simulate Emergency Scenarios

```dart
// Test medium risk
await _emergencyService.triggerEmergencyResponse(
  riskLevel: EmergencyRiskLevel.medium,
  reason: 'TEST: Simulated geofence exit',
  metadata: {'test_mode': true},
);

// Test high risk
await _emergencyService.triggerEmergencyResponse(
  riskLevel: EmergencyRiskLevel.high,
  reason: 'TEST: Simulated location anomaly',
  metadata: {'test_mode': true},
);

// Test critical risk
await _emergencyService.triggerEmergencyResponse(
  riskLevel: EmergencyRiskLevel.critical,
  reason: 'TEST: Simulated panic button',
  metadata: {'test_mode': true},
);
```

## Best Practices

1. **Always Verify Contacts**: Ensure phone numbers and emails are correct
2. **Test Regularly**: Run test scenarios to verify the system works
3. **Balance Sensitivity**: Avoid false positives while ensuring true emergencies are caught
4. **Privacy First**: Only share necessary information with contacts
5. **Clear Communication**: Make sure contacts know what to expect
6. **Regular Updates**: Keep contact information current
7. **Multiple Channels**: Use phone, SMS, and email for redundancy
8. **Audit Trail**: Review emergency events periodically

## Troubleshooting

### No Contacts Notified
- Verify contacts are added in `/emergency-contacts`
- Check Firestore security rules allow access
- Ensure user is authenticated

### Notifications Not Sent
- Verify notification preferences are enabled
- Check Firestore for `emergency_notifications` collection entries
- Review Firebase Cloud Functions logs for errors

### False Positives
- Adjust risk thresholds in `wandering_prediction_service.dart`
- Review emergency events to identify patterns
- Consider environmental factors (poor GPS signal, etc.)

## Support

For additional help:
- Review `/diagnostics` screen for system health
- Check Firestore console for data
- Review comprehensive documentation in `docs/EMERGENCY_RESPONSE_SYSTEM.md`
