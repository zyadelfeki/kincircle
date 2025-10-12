# Emergency Response System - Quick Start Guide

## 🚀 5-Minute Setup

### 1. Navigate to Emergency Contacts
```dart
Navigator.of(context).pushNamed('/emergency-contacts');
```

### 2. Add a Contact (Code)
```dart
final service = EmergencyResponseService();

await service.addEmergencyContact(
  EmergencyContact(
    id: '',
    userId: '',
    name: 'Mom',
    phoneNumber: '+1-555-0100',
    email: 'mom@example.com',
    type: EmergencyContactType.family,
    priority: EmergencyContactPriority.primary,
    notifyByPhone: true,
    notifyBySms: true,
    notifyByEmail: false,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  ),
);
```

### 3. Trigger Emergency Response
```dart
await service.triggerEmergencyResponse(
  riskLevel: EmergencyRiskLevel.high,
  reason: 'User needs immediate assistance',
  metadata: {'source': 'panic_button'},
);
```

## 📊 Risk Levels Cheat Sheet

| Level | Trigger | Contacts Notified | Use Case |
|-------|---------|-------------------|----------|
| **Medium** | Distance >1km, Minor deviation | Primary Family | Early warning |
| **High** | Multiple factors | Family + Medical | Possible medical need |
| **Critical** | Severe indicators | All contacts | Immediate action |

## 🎯 Common Use Cases

### Panic Button
```dart
ElevatedButton(
  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
  onPressed: () => EmergencyResponseService().triggerEmergencyResponse(
    riskLevel: EmergencyRiskLevel.critical,
    reason: 'Panic button activated',
  ),
  child: Text('EMERGENCY'),
);
```

### Location Monitoring
```dart
final wanderingService = WanderingPredictionService();

await wanderingService.monitorAndRespond(
  currentPosition: position,
  lastKnownPosition: lastPosition,
);
```

### Geofence Exit
```dart
await EmergencyResponseService().triggerEmergencyResponse(
  riskLevel: EmergencyRiskLevel.medium,
  reason: 'Left safe zone: Home',
  metadata: {'geofence': 'home', 'lat': 37.7749, 'lng': -122.4194},
);
```

## 🔧 Firebase Setup

### Deploy Indexes
```bash
firebase deploy --only firestore:indexes
```

### Deploy Rules
```bash
firebase deploy --only firestore:rules
```

### Set Remote Config
```
emergency_response_enabled: true
wandering_prediction_enabled: true
```

## 📦 Dependencies

All dependencies are already in `pubspec.yaml`:
- ✅ `firebase_core`
- ✅ `firebase_auth`
- ✅ `cloud_firestore`
- ✅ `geolocator`

## 📱 Contact Types

```dart
enum EmergencyContactType {
  family,        // 👨‍👩‍👧‍👦 Parents, siblings, spouse
  medical,       // 🏥 Doctors, therapists
  firstResponder // 🚨 Emergency services
}
```

## 🎖️ Priority Levels

```dart
enum EmergencyContactPriority {
  primary,   // Notify first
  secondary, // Notify if primary unavailable
  tertiary   // Last resort
}
```

## 🛡️ Security

- ✅ User-scoped data (users can only see their contacts)
- ✅ Encrypted at rest (Firestore)
- ✅ Audit trail (all events logged)
- ✅ Immutable events (can't be deleted/modified)

## 📚 Full Documentation

- **Architecture**: `docs/EMERGENCY_RESPONSE_ARCHITECTURE.md`
- **Technical**: `docs/EMERGENCY_RESPONSE_SYSTEM.md`
- **Usage**: `docs/EMERGENCY_RESPONSE_USAGE.md`
- **Summary**: `docs/EMERGENCY_RESPONSE_SUMMARY.md`

## 🧪 Testing

```bash
# Run all tests
flutter test

# Run specific test
flutter test test/emergency_response_service_test.dart
```

## 🐛 Troubleshooting

| Issue | Solution |
|-------|----------|
| No contacts notified | Check authentication & contacts exist |
| Notifications not sent | Verify Firestore rules deployed |
| False positives | Adjust risk thresholds |

## 💡 Pro Tips

1. **Start simple**: Add 1-2 primary family contacts first
2. **Test in dev**: Use test contacts with notifications disabled
3. **Monitor events**: Check `emergency_events` collection in Firestore
4. **Tune thresholds**: Adjust risk scores based on false positive rate
5. **Review audit trail**: Regularly check notification logs

## 🎬 Quick Demo

```dart
// Complete emergency response flow
void demonstrateEmergencySystem() async {
  final service = EmergencyResponseService();
  
  // 1. Add contact
  await service.addEmergencyContact(
    EmergencyContact(
      id: '', userId: '',
      name: 'Emergency Contact',
      phoneNumber: '+1-555-0100',
      type: EmergencyContactType.family,
      priority: EmergencyContactPriority.primary,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
  );
  
  // 2. Trigger response
  final results = await service.triggerEmergencyResponse(
    riskLevel: EmergencyRiskLevel.high,
    reason: 'Demo: System test',
  );
  
  // 3. Check results
  print('Notified ${results.length} contacts');
  for (var result in results) {
    print('${result.contactName}: ${result.success ? "✓" : "✗"}');
  }
}
```

## ⚡ Quick Commands

```dart
// Get all contacts
Stream<List<EmergencyContact>> contacts = service.getEmergencyContacts();

// Delete contact
await service.deleteEmergencyContact(contactId);

// Update contact
await service.updateEmergencyContact(updatedContact);

// Assess risk (without triggering)
WanderingRiskAssessment risk = await wanderingService.assessWanderingRisk(
  currentPosition: position,
);
print('Risk: ${risk.riskLevel.name} (${risk.riskScore})');
```

---

**Need help?** Check the full documentation or review the test files for examples.
