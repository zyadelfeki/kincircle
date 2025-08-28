# Driver Safety Module

A privacy-first, on-device feature that detects risky driving events and produces a weekly safety score.

## Overview

- On-device detection using accelerometer and gyroscope; optional TFLite model.
- Incidents stored locally in Hive only (type, timestamp, severity). No raw sensor data leaves the device.
- Weekly anonymized summary uploaded: { harsh_braking_count, rapid_accel_count }.
- Cloud Function aggregates weekly summaries and writes `driverSafetyScore` (0–100) to `users/{uid}`.

## App Components

- Service: `lib/services/driver_safety/driver_safety_service.dart`
- UI: `lib/screens/driving/driving_mode_screen.dart`, `lib/screens/driving/safety_report_screen.dart`, hub `driver_safety_hub_screen.dart`
- Backend: `functions/src/index.ts` → `calculateDriverSafetyScore`

## Remote Config Flags

- `driver_safety_enabled` (bool, default true) – master toggle
- `driver_safety_threshold_brake` (double, default 0.7)
- `driver_safety_threshold_accel` (double, default 0.7)

## Data

- Hive box: `driver_incidents`
  - `{ timestamp: ISO8601 string, type: 'harsh_brake'|'rapid_accel'|'sharp_turn', score: double }`
- Firestore summary doc: `users/{uid}/driver_safety_summaries/{YYYY-MM-DD}`
  - `{ period_start: 'YYYY-MM-DD', periodStart: Timestamp, harsh_braking_count: int, rapid_accel_count: int, createdAt, source: 'mobile' }`
- User doc field:
  - `driverSafetyScore` (int 0–100), `driverSafetyScoreUpdatedAt`

## QA Notes

- Debug-only button on Safety Report: "Upload Summary Now"
- Sign-in attempts weekly upload via `uploadWeeklySummaryIfNeeded()`

## Privacy

- No raw sensor streams leave the device.
- Only aggregate counts are uploaded weekly.

## Troubleshooting

- Ensure Google Maps API key is set in AndroidManifest if dashboard map is used.
- If app shows black screen before `main()`, rebuild the app (clean → pub get → run) after manifest edits.
- Verify Remote Config is initialized before use.
