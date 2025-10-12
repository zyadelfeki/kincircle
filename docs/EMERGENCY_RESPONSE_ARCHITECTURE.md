# Emergency Response System - Architecture Diagram

## System Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                    Emergency Response System                         │
│                     (AI-Powered Crisis Coordination)                 │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│                           USER INTERFACE                             │
├─────────────────────────────────────────────────────────────────────┤
│  EmergencyContactsScreen (/emergency-contacts)                       │
│  ├── Add Contact Dialog                                              │
│  ├── Edit Contact Dialog                                             │
│  ├── Contact List View (StreamBuilder)                               │
│  └── Delete Confirmation Dialog                                      │
└─────────────────────────────────────────────────────────────────────┘
                                   │
                                   ↓
┌─────────────────────────────────────────────────────────────────────┐
│                          SERVICE LAYER                               │
├─────────────────────────────────────────────────────────────────────┤
│                                                                       │
│  ┌────────────────────────────────────────────────────────────┐     │
│  │  EmergencyResponseService                                   │     │
│  │  ├── triggerEmergencyResponse()                             │     │
│  │  ├── filterContactsByRiskLevel()                            │     │
│  │  ├── notifyContact()                                        │     │
│  │  ├── logEmergencyEvent()                                    │     │
│  │  └── CRUD operations for contacts                           │     │
│  └────────────────────────────────────────────────────────────┘     │
│                                                                       │
│  ┌────────────────────────────────────────────────────────────┐     │
│  │  WanderingPredictionService                                 │     │
│  │  ├── assessWanderingRisk()                                  │     │
│  │  │   ├── Distance analysis                                  │     │
│  │  │   ├── Time analysis                                      │     │
│  │  │   ├── Movement pattern analysis                          │     │
│  │  │   └── Speed analysis                                     │     │
│  │  ├── monitorAndRespond()                                    │     │
│  │  └── determineRiskLevel()                                   │     │
│  └────────────────────────────────────────────────────────────┘     │
│                                                                       │
└─────────────────────────────────────────────────────────────────────┘
                                   │
                                   ↓
┌─────────────────────────────────────────────────────────────────────┐
│                          DATA MODELS                                 │
├─────────────────────────────────────────────────────────────────────┤
│                                                                       │
│  EmergencyContact                    EmergencyRiskLevel              │
│  ├── id                              ├── medium                      │
│  ├── userId                          ├── high                        │
│  ├── name                            └── critical                    │
│  ├── phoneNumber                                                     │
│  ├── email                           WanderingRiskLevel              │
│  ├── type: {family, medical,         ├── low                         │
│  │           firstResponder}          ├── medium                     │
│  ├── priority: {primary,              ├── high                       │
│  │             secondary,              └── critical                  │
│  │             tertiary}                                             │
│  └── notification preferences        WanderingRiskAssessment         │
│                                      ├── riskLevel                   │
│                                      ├── riskScore                   │
│                                      ├── reason                      │
│                                      └── factors                     │
│                                                                       │
└─────────────────────────────────────────────────────────────────────┘
                                   │
                                   ↓
┌─────────────────────────────────────────────────────────────────────┐
│                     FIREBASE INTEGRATION                             │
├─────────────────────────────────────────────────────────────────────┤
│                                                                       │
│  Firestore Collections:                                              │
│  ┌────────────────────────────────────────────────────────────┐     │
│  │  emergency_contacts                                         │     │
│  │  ├── Indexed by: userId, priority                           │     │
│  │  ├── Security: User-scoped read/write                       │     │
│  │  └── Real-time updates via StreamBuilder                    │     │
│  └────────────────────────────────────────────────────────────┘     │
│                                                                       │
│  ┌────────────────────────────────────────────────────────────┐     │
│  │  emergency_notifications                                    │     │
│  │  ├── Indexed by: contactId, timestamp                       │     │
│  │  ├── Security: Write-once, read-only                        │     │
│  │  └── Tracks all notification attempts                       │     │
│  └────────────────────────────────────────────────────────────┘     │
│                                                                       │
│  ┌────────────────────────────────────────────────────────────┐     │
│  │  emergency_events                                           │     │
│  │  ├── Indexed by: userId, timestamp                          │     │
│  │  ├── Security: Audit trail, immutable                       │     │
│  │  └── Contains full context of each event                    │     │
│  └────────────────────────────────────────────────────────────┘     │
│                                                                       │
│  Remote Config:                                                      │
│  ├── emergency_response_enabled: boolean                            │
│  └── wandering_prediction_enabled: boolean                          │
│                                                                       │
└─────────────────────────────────────────────────────────────────────┘
```

## Data Flow Diagrams

### 1. Emergency Contact Management Flow

```
User Action                    Service                    Firestore
    │                             │                           │
    ├─ Add Contact ──────────────►│                           │
    │                             ├─ Validate Data            │
    │                             ├─ Create Document ────────►│
    │                             │                           ├─ Store
    │                             │◄────── Doc ID ────────────┤
    │◄──── Success ───────────────┤                           │
    │                             │                           │
    ├─ Edit Contact ─────────────►│                           │
    │                             ├─ Update Document ────────►│
    │                             │                           ├─ Update
    │◄──── Success ───────────────┤                           │
    │                             │                           │
    ├─ Delete Contact ───────────►│                           │
    │                             ├─ Delete Document ────────►│
    │                             │                           ├─ Remove
    │◄──── Success ───────────────┤                           │
    │                             │                           │
    ├─ View Contacts ────────────►│                           │
    │                             ├─ Stream Query ───────────►│
    │                             │◄──── Real-time ───────────┤
    │◄──── Live Updates ──────────┤         Updates           │
```

### 2. Emergency Response Cascade Flow

```
Trigger Event              Wandering Service         Emergency Service        Firestore
     │                           │                           │                    │
     ├─ Location Update ────────►│                           │                    │
     │                           ├─ Assess Risk             │                    │
     │                           │   ├─ Distance             │                    │
     │                           │   ├─ Time                 │                    │
     │                           │   ├─ Movement             │                    │
     │                           │   └─ Speed                │                    │
     │                           ├─ Risk Score = 0.65        │                    │
     │                           │   (HIGH RISK)             │                    │
     │                           │                           │                    │
     │                           ├─ Trigger Response ───────►│                    │
     │                           │                           ├─ Get Contacts     │
     │                           │                           │   (Query) ────────►│
     │                           │                           │◄─── Contacts ──────┤
     │                           │                           │                    │
     │                           │                           ├─ Filter by Risk   │
     │                           │                           │   Level (HIGH)     │
     │                           │                           │   → Family +       │
     │                           │                           │     Medical        │
     │                           │                           │                    │
     │                           │                           ├─ Sort by Priority │
     │                           │                           │                    │
     │                           │                           ├─ Notify Contacts  │
     │                           │                           │   ├─ Contact 1 ───►│
     │                           │                           │   ├─ Contact 2 ───►│
     │                           │                           │   └─ Contact 3 ───►│
     │                           │                           │                    │
     │                           │                           ├─ Log Event ───────►│
     │                           │                           │                    │
     │                           │◄──── Results ─────────────┤                    │
     │◄──── Notification Sent ───┤                           │                    │
```

### 3. Risk Assessment Decision Tree

```
                        Location Update
                              │
                              ↓
                    ┌─────────────────┐
                    │ Calculate Risk  │
                    │     Score       │
                    └─────────────────┘
                              │
              ┌───────────────┼───────────────┐
              ↓               ↓               ↓
        [Score < 0.4]   [0.4 ≤ Score < 0.6] [Score ≥ 0.6]
              ↓               ↓               ↓
        ┌──────────┐    ┌──────────┐    ┌──────────┐
        │   LOW    │    │  MEDIUM  │    │   HIGH   │
        │   RISK   │    │   RISK   │    │   RISK   │
        └──────────┘    └──────────┘    └──────────┘
              │               ↓               ↓
              ↓         [Score ≥ 0.8?]       │
        No Action            │               │
                      ┌──────┴──────┐        │
                      ↓             ↓        │
                   NO             YES        │
                    │               │        │
                    ↓               ↓        ↓
            ┌──────────────┐ ┌──────────────────────┐
            │Medium Alert  │ │   Critical Alert     │
            │Primary Family│ │   Full Cascade       │
            │   Only       │ │ (All Contacts)       │
            └──────────────┘ └──────────────────────┘
                    │               │        │
                    └───────┬───────┴────────┘
                            ↓
                  Trigger Emergency Response
```

### 4. Contact Priority Cascade

```
Risk Level: MEDIUM
  └─► Filter: Family + Priority.Primary
       ↓
       Contact 1 (Family, Primary)
       └─► Notify via: Phone, SMS

Risk Level: HIGH
  └─► Filter: (Family OR Medical) + All Priorities
       ↓
       Contact 1 (Family, Primary)
       Contact 2 (Family, Secondary)
       Contact 3 (Medical, Primary)
       └─► Notify via: Phone, SMS, Email

Risk Level: CRITICAL
  └─► Filter: All Types + All Priorities
       ↓
       Contact 1 (Family, Primary)
       Contact 2 (Family, Secondary)
       Contact 3 (Medical, Primary)
       Contact 4 (Medical, Secondary)
       Contact 5 (FirstResponder, Primary)
       Contact 6 (FirstResponder, Tertiary)
       └─► Notify via: All channels + Escalation
```

## Component Dependencies

```
main.dart
  └─► EmergencyContactsScreen
       └─► EmergencyResponseService
            ├─► FirebaseAuth
            ├─► FirebaseFirestore
            └─► EmergencyContact (model)

WanderingPredictionService
  ├─► EmergencyResponseService
  ├─► Geolocator
  └─► Position (from geolocator)

RemoteConfigService
  └─► FirebaseRemoteConfig
       ├─► emergency_response_enabled
       └─► wandering_prediction_enabled
```

## Testing Architecture

```
Unit Tests
  ├─► emergency_response_service_test.dart
  │    ├─► Authentication tests
  │    ├─► Risk filtering tests
  │    ├─► Model serialization tests
  │    └─► Enum validation tests
  │
  ├─► wandering_prediction_service_test.dart
  │    ├─► Risk assessment tests
  │    ├─► Factor detection tests
  │    ├─► Threshold validation tests
  │    └─► Movement analysis tests
  │
  └─► emergency_contacts_screen_test.dart
       ├─► Widget rendering tests
       ├─► UI component tests
       └─► StreamBuilder tests

Integration Tests (Future)
  ├─► End-to-end contact management
  ├─► Complete response cascade
  ├─► Firestore integration
  └─► Real-time updates
```

## Security & Privacy Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Security Layers                          │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  Layer 1: Authentication                                      │
│  └─► Firebase Auth required for all operations               │
│                                                               │
│  Layer 2: Authorization (Firestore Rules)                    │
│  ├─► Users can only access their own contacts                │
│  ├─► Events are write-once, read-by-owner                    │
│  └─► Notifications are immutable                             │
│                                                               │
│  Layer 3: Data Encryption                                    │
│  ├─► At rest: Firestore encryption                           │
│  └─► In transit: TLS/SSL                                     │
│                                                               │
│  Layer 4: Audit Trail                                        │
│  ├─► All emergency events logged                             │
│  ├─► Notification attempts tracked                           │
│  └─► Immutable event history                                 │
│                                                               │
│  Layer 5: Privacy Controls                                   │
│  ├─► User-controlled contact data                            │
│  ├─► Opt-in notification preferences                         │
│  └─► Feature flags for granular control                      │
│                                                               │
└─────────────────────────────────────────────────────────────┘
```

## Scalability Considerations

- **Firestore Indexes**: Optimized for common queries
- **Real-time Streams**: Efficient change detection
- **Batch Operations**: Minimize write costs
- **Caching**: Remote config with 1-hour minimum fetch interval
- **Error Handling**: Graceful degradation on failures
- **Rate Limiting**: Built-in Firebase protections

## Future Architecture Enhancements

1. **Cloud Functions Integration**
   - Serverless notification dispatch
   - SMS via Twilio
   - Email via SendGrid
   - Phone calls via automated system

2. **ML/AI Enhancement**
   - Personalized risk thresholds
   - Pattern learning from user behavior
   - Predictive modeling for better accuracy

3. **Multi-platform Support**
   - iOS native notifications
   - Android native notifications
   - Web push notifications
   - Wearable device integration

4. **Advanced Features**
   - Geofencing integration
   - Voice SOS integration
   - Medical history context
   - Multi-language support
