# KinCircle Pro Vision (V2)

This document outlines the V2 roadmap to evolve KinCircle from MVP to a proactive, privacy-forward safety platform. It focuses on a real-time Proactive Safety Engine, Zero-Knowledge security architecture, and an Interactive Privacy Tour.

## 1) Proactive Safety Engine: Predictive ETA & Risk-Aware Journeys

### Objectives

- Predict journey risks (delays, hazards) and ETA reliability.
- Provide proactive, explainable alerts with minimal noise.
- Control cost via caching, batching, and graceful degradation.

### Architecture Overview

- Inputs
  - Google Directions API: routes, traffic, ETAs, alternatives.
  - Weather API (e.g., OpenWeather/NOAA): precipitation, wind, severe alerts.
  - Optional Feeds: road hazards (Waze-like), school zones, construction.
  - User Context: historical journeys, geofences, time-of-day, day-of-week.
- Feature Pipeline
  - Segment route into polylines; enrich with traffic/weather per segment.
  - Derived features: congestion indices, weather severity, school-zone overlap, historical variance for user/time.
  - Labels: delayed trips, detours, incident reports (from user feedback/telemetry).
- Vertex AI (GCP)
  - Model: Gradient boosting or AutoML Tabular for risk_score (0–1) and eta_reliability (0–1).
  - Online Inference: Deployed endpoint; include request_id, top features (for explainability).
  - Training: BigQuery datasets (journeys, segments, outcomes). Weekly retrain with drift checks.
- Serving Layer
  - Strategies: cache recent route results; pre-warm popular corridors; fall back to rules if quota limits hit.
  - Thresholds: risk bands (low/med/high) with user-tunable sensitivity.
  - Observability: metrics on alert precision/recall, user feedback loop.

### Data Flow

1. Client requests route (or detects journey start).
2. Server collects route + context, computes features, calls Vertex endpoint.
3. Combine segment-level risk into journey risk_score; compute explanation summary.
4. Send proactive alert if above threshold; include top contributing factors.
5. Collect feedback (true/false positive) and store in BigQuery for retraining.

### Privacy & Cost Controls

- Respect consent and background limits. Disable in low-power/low-data modes.
- Use regional endpoints, response compression, and exponential backoff.
- Log only metadata needed for model health; minimize PII in model tables.

## 2) Advanced Security & Trust: End-to-End Encryption (E2EE)

### Zero-Knowledge Design

- Keys
  - Per-family data key (AES-GCM 256).
  - Each member stores the family key encrypted with their public key (X25519/Curve25519).
  - Server never sees plaintext keys; only encrypted envelopes.
- Operations
  - On join: provision a wrapped family key for the new member; rotate or re-wrap as needed.
  - On leave/removal: rotate the family key; re-wrap for remaining members; tombstone prior envelopes.
  - Recovery: social recovery or secure cloud backup of user private key (opt-in).
- Implementation Plan
  - Phase A: Client-side envelope encryption for location events; decrypt-on-view.
  - Phase B: Extend to alerts, messages, and attachments; add batching and streaming.
  - Phase C: Key rotation policies; cryptographic logs of access/changes.
- Perf/UX
  - Keep payloads small; leverage background processing; progressive rendering post-decrypt.
  - Clear UX for key backup, transfer, and revocation.

## 3) Interactive & Just-in-Time Consent: Privacy Tour

### Goals

- Replace one-shot consent with a guided, understandable flow.
- Provide context for each permission at the moment it’s needed.

### Flow (3–4 screens)

1. Why We Ask
   - What KinCircle does and how it uses data to keep families connected and safer.
   - Benefits and controls overview.
2. Location & Background Access
   - What is collected (precise location), when (foreground/background), and why (live updates, safety).
   - Controls: pause sharing, per-circle visibility, battery optimization hints.
3. Sensors & Driver Safety
   - Accelerometer/gyroscope for detecting harsh events; on-device inference where possible.
   - Transparent data handling; how to turn it off.
4. Your Control
   - Consent toggles, data export/deletion, and links to Privacy Policy and Terms.

### Implementation Notes

- Store per-permission consent states with timestamps.
- Provide a “revisit tour” entry in Settings.
- Use non-technical, friendly copy with iconography and optional “learn more”.

## Milestones & KPIs

- M1 (30–45 days): Feature pipeline MVP (Directions + Weather), risk scoring POC, feedback capture.
- M2 (60–90 days): Online inference + proactive alerts; Interactive Privacy Tour v1.
- M3 (90–120 days): E2EE Phase A (location); risk model v2 with drift monitors; partner demo.
- KPIs: Alert precision/recall, user engagement with alerts, consent completion rate, crash-free sessions, MAU growth.

---

Appendix

- Cost management: cache strategy, quota guards, and regional endpoints.
- Compliance: privacy-by-design, minimal PII in ML tables, audit trails, and opt-in encryption.
