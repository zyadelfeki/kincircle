# Emergency Response System Documentation

## Overview

The Emergency Response System is an AI-powered crisis coordination feature that connects family members, medical professionals, and first responders during invisible disability crises. The system uses risk-based response levels and wandering prediction to automatically trigger appropriate emergency responses.

## Architecture

### Components

1. **Emergency Contact Model** (`lib/models/emergency_contact.dart`)
   - Defines contact hierarchy with types: Family, Medical, First Responder
   - Supports multiple notification methods (phone, SMS, email)
   - Includes priority levels: Primary, Secondary, Tertiary

2. **Emergency Response Service** (`lib/services/emergency_response_service.dart`)
   - Coordinates emergency responses based on risk levels
   - Implements contact filtering and notification cascade
   - Logs emergency events for audit trail

3. **Wandering Prediction Service** (`lib/services/wandering_prediction_service.dart`)
   - Analyzes location patterns to detect wandering behavior
   - Calculates risk scores based on multiple factors
   - Automatically triggers emergency responses when thresholds are met

4. **Emergency Contacts Screen** (`lib/screens/emergency/emergency_contacts_screen.dart`)
   - User interface for managing emergency contacts
   - Supports adding, editing, and deleting contacts
   - Real-time updates via Firestore streams

## Risk-Based Response Levels

### Medium Risk
- **Triggers**: Distance > 1km from safe location, slow/fast movement
- **Contacts Notified**: Primary family contacts only
- **Use Case**: Early warning, potential confusion

### High Risk
- **Triggers**: Distance > 1km + stale location (>30 min)
- **Contacts Notified**: Family + Medical professionals
- **Use Case**: Possible disorientation, medical attention may be needed

### Critical Risk
- **Triggers**: Multiple risk factors combined (high risk score)
- **Contacts Notified**: Full cascade (Family + Medical + First Responders)
- **Use Case**: Severe emergency, immediate action required

## Wandering Detection Factors

The system analyzes multiple factors to assess wandering risk:

1. **Distance from Safe Location**: Risk increases beyond 1km
2. **Time Since Last Update**: Risk increases after 30 minutes
3. **Movement Pattern Variance**: Erratic movement indicates confusion
4. **Speed Analysis**: 
   - Very slow (<1 m/s): Possible disorientation
   - Unusually fast (>10 m/s): Concerning behavior

## Data Storage

### Firestore Collections

#### `emergency_contacts`
```
{
  userId: string,
  name: string,
  phoneNumber: string,
  email?: string,
  type: 'family' | 'medical' | 'firstResponder',
  priority: 'primary' | 'secondary' | 'tertiary',
  notifyByPhone: boolean,
  notifyByEmail: boolean,
  notifyBySms: boolean,
  createdAt: timestamp,
  updatedAt: timestamp
}
```

#### `emergency_notifications`
```
{
  contactId: string,
  contactName: string,
  phoneNumber: string,
  email?: string,
  riskLevel: 'medium' | 'high' | 'critical',
  reason: string,
  metadata: object,
  timestamp: timestamp,
  status: 'pending' | 'sent' | 'failed'
}
```

#### `emergency_events`
```
{
  userId: string,
  riskLevel: 'medium' | 'high' | 'critical',
  reason: string,
  contactIds: string[],
  metadata: object,
  timestamp: timestamp
}
```

## Remote Config Flags

- `emergency_response_enabled`: Master toggle for emergency response features
- `wandering_prediction_enabled`: Toggle for wandering detection and prediction

## Integration Points

### Location Service Integration
The wandering prediction service integrates with the existing location service to:
- Monitor real-time position updates
- Track movement patterns
- Detect anomalies in user behavior

### Alert System Integration
Emergency responses create alerts in the existing alert system:
- Visible in `/alerts` screen
- Push notifications sent to family members
- Audit trail maintained for compliance

## Usage

### Adding Emergency Contacts

1. Navigate to Emergency Contacts screen: `/emergency-contacts`
2. Tap the "+" button in the app bar
3. Fill in contact details:
   - Name (required)
   - Phone number (required)
   - Email (optional)
   - Contact type
   - Priority level
   - Notification preferences
4. Save the contact

### Triggering Emergency Response

The system can be triggered:

1. **Automatically**: Via wandering prediction when risk thresholds are met
2. **Manually**: Through service API call:
   ```dart
   await emergencyService.triggerEmergencyResponse(
     riskLevel: EmergencyRiskLevel.high,
     reason: 'Manual emergency trigger',
     metadata: {'source': 'panic_button'},
   );
   ```

## Testing

### Unit Tests
- `test/emergency_response_service_test.dart`: Service logic tests
- `test/wandering_prediction_service_test.dart`: Risk assessment tests
- `test/emergency_contacts_screen_test.dart`: UI widget tests

### Integration Testing

To test the complete emergency response cascade:

1. Add test emergency contacts
2. Simulate location updates with risk factors
3. Verify notifications are created in Firestore
4. Check emergency events are logged

## Privacy & Compliance

- All emergency events are logged for audit purposes
- Contact data is encrypted at rest in Firestore
- Notification logs preserve privacy while maintaining accountability
- Users have full control over contact management

## Future Enhancements

1. **SMS/Phone Integration**: Implement actual SMS and phone call notifications via Twilio
2. **Email Notifications**: Integrate SendGrid or AWS SES for email alerts
3. **Geofencing Integration**: Trigger responses when leaving safe zones
4. **ML-Enhanced Prediction**: Train models on user-specific patterns
5. **Medical History Integration**: Include relevant medical info in notifications
6. **Emergency Contact Validation**: Verify phone numbers and email addresses

## Support

For issues or questions about the emergency response system:
- Review logs in Firestore console
- Check `/diagnostics` screen for system health
- Review emergency events in `emergency_events` collection
