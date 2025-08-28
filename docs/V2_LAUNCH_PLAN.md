# KinCircle V2 Launch Plan

## 1. Final QA Checklist for V2 Features

### AI Driver Safety Module

- Start and end a drive
  - Pre-conditions: Logged in; sensors enabled; app in foreground.
  - Steps:
    - Navigate: Driver Safety → Start a Drive.
    - Move phone to simulate acceleration/braking for 30–60 seconds.
    - Tap End Drive.
  - Expected:
    - Status changes to “Driving… collecting data,” then “Drive ended.”
    - No app crash or ANR; battery impact minimal in short sessions.

- Verify incidents are saved locally (Hive)
  - Steps:
    - Driver Safety → Safety Report.
  - Expected:
    - A list of incidents appears (Harsh Braking, Rapid Acceleration) with timestamps and scores.
    - No network dependency; works offline.

- Trigger the weekly summary upload manually (QA-only)
  - Steps:
    - Build a debug build; open Safety Report.
    - Press “Upload Summary Now.”
  - Expected:
    - Snackbar: “Weekly summary uploaded.”
    - Firestore: users/{uid}/driver_safety_summaries/{YYYY-MM-DD} exists with fields:
      - period_start (string), periodStart (Timestamp)
      - harsh_braking_count (int), rapid_accel_count (int)
      - createdAt (serverTimestamp), source: "mobile"

- Verify backend calculates and displays driverSafetyScore
  - Steps:
    - Ensure Cloud Function `calculateDriverSafetyScore` is deployed.
    - For faster testing, add a recent summary (manual upload or admin write) and temporarily run the function via emulator or reschedule (optional).
    - Open Safety Report.
  - Expected:
    - Firestore users/{uid}.driverSafetyScore is populated.
    - Safety Report shows “Weekly Driver Safety Score: N / 100.”

### AI Smart Alerts

- Consent flow + enable feature
  - Steps:
    - Sign in; open Settings → AI Consent; accept.
    - Ensure Remote Config defaults: smart_alerts_enabled=true; ml_alerts_enabled per rollout.
  - Expected:
    - ML features remain disabled until consent; after consent, ML toggle allowed (if enabled by config).

- ML-powered alert end-to-end
  - Steps:
    - With `ml_alerts_enabled=true` and endpoint configured, simulate a location update at an unusual time/place.
    - Alternatively, use a test user with conditions that produce an anomaly score > threshold.
  - Expected:
    - `alerts` collection receives an “AI Smart Alert: Unusual activity detected!”
    - In-app banner shows the alert and navigates to details.

- Rule-based fallback (when ml_alerts_enabled=false)
  - Steps:
    - Disable ml_alerts_enabled; simulate entering a geofence outside allowed hours.
  - Expected:
    - Rule-based alert written; no duplicate ML alert.

- Duplicate prevention
  - Steps:
    - Enable ML flag; trigger same scenario.
  - Expected:
    - Rule-based function skips when ML is enabled; only ML alert may appear.

## 2. V2 Marketing & Communications Plan

### App Store “What’s New”

- Introducing AI Driver Safety Score! Get a simple weekly score (0–100) powered by on-device detection of harsh braking and rapid acceleration—your data stays on your phone.
- Smarter Alerts: Our AI Smart Alerts now better recognize unusual activity, so you can take action faster.
- Performance and reliability improvements.

### Blog Post (≈400 words)

Title: KinCircle V2 is Here: Introducing a New Era of Proactive Family Safety

Today, we’re excited to launch KinCircle V2—our biggest leap forward in proactive family safety. With this release, we’re bringing two powerful capabilities to your phone: the AI Driver Safety Score and an upgraded AI Smart Alerts engine.

The AI Driver Safety Score provides a simple weekly snapshot (0–100) of driving behavior, focusing on two high-impact events: harsh braking and rapid acceleration. Unlike traditional telematics, KinCircle runs detection on your device and stores only an anonymized summary in the cloud—never raw sensor data. That means you get meaningful feedback for safer driving while keeping your privacy at the center.

We’ve also upgraded AI Smart Alerts to help families identify unusual activity more quickly. Whether it’s being in a place at an unexpected time or a sudden deviation from the routine, the app can surface a clear, timely alert that’s easy to act on. For those who participated in our beta, your feedback helped us tune sensitivity, reduce noise, and improve clarity across the app.

This release also includes under-the-hood enhancements to performance, battery usage, and reliability. We’ve streamlined both app and backend paths so everything feels fast and dependable day to day. Over the coming weeks, we’ll roll out additional improvements based on your feedback and real-world usage.

KinCircle V2 is a milestone—but it’s just the start. Our mission is to help families feel connected, informed, and safe. If you’re new to KinCircle, welcome! If you’ve been with us since the beginning, thank you for your trust and support. Try the new Driver Safety Score and Smarter Alerts, and let us know what you think.

Stay safe—and stay connected.

### Email to Users

Subject: Meet KinCircle V2 — Driver Safety Score + Smarter Alerts

Hi there,

We’ve just launched KinCircle V2 with two major updates:

1. AI Driver Safety Score (0–100)

- Detects harsh braking and rapid acceleration on-device
- Sends only an anonymized weekly summary—your raw data never leaves your phone

1. Smarter Alerts

- Faster, clearer alerts for unusual activity
- Built to help you act quickly and confidently

Update the app to get started. Open Driver Safety to start a drive and view your weekly score, and visit Settings to enable the AI Smart Alerts experience.

Thanks for being part of KinCircle. Your feedback helps us keep families safe, connected, and in the know.

— The KinCircle Team

## 3. V2 Release Checklist

- Final QA sign-off
  - All test cases above pass on both iOS and Android devices.
  - No open P0/P1 bugs.
  - Battery and performance spot-check with short and long drives.

- Feature flag rollout
  - Confirm Remote Config defaults:
    - smart_alerts_enabled: true
    - ml_alerts_enabled: start at 10% of users → 50% → 100% (with gating on consent)
    - Any experimental flags: off for GA.
  - Staged rollout plan:
    - Day 0: 10% with enhanced logging and on-call coverage.
    - Day 2: 50% if crash-free sessions ≥ 99.5% and alert precision ≥ 85%.
    - Day 5: 100% if metrics hold.

- Store submission & comms
  - Update screenshots and “What’s New” text in App Store / Google Play.
  - Prepare blog post and schedule email announcement.
  - Coordinate social posts (launch day + D+3 recap).

- Monitoring & observability
  - App metrics: crash-free sessions, ANR rate, cold start time, battery usage.
  - AI metrics: alert precision/recall, driverSafetyScore distribution.
  - Backend: Cloud Functions errors/latency, Firestore/Functions costs (see Cloud Cost Monitoring Guide).
  - Set alerts on spikes in write volume and function execution time.

- Launch day process
  - 09:00: Go/No-Go; confirm CI/CD artifacts built; Remote Config staged for 10%.
  - 09:30: Submit phased rollout on stores (if applicable).
  - 10:00–18:00: Live monitoring window with owner on-call; capture issues in a shared doc.
  - D+1: Review metrics; decide on advancing to 50%.
  - D+3: Review metrics; decide on advancing to 100%.

- Post-launch
  - Run Sprint Retro using AI_SPRINT_RETROSPECTIVE.md.
  - Capture user feedback; schedule hotfixes if necessary.
  - Archive V2 launch artifacts and tag the release in git.
