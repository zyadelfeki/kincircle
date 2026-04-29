# KinCircle Engineering Recovery Plan

## Strategic Intent: System Integration over Fragmented Patching
The root cause of current instability is "fragmented assembly syndrome"—features built in isolation by multiple AI sessions without a cohesive integration pass. This plan shifts from patching bugs to establishing a verified system baseline, then repairing issues with explicit success gates.

---

## Phase 0: Baseline Stabilization (Prerequisites)
**Goal:** Ensure the project is compilable, testable, and has the infrastructure bridges for future work.

- [ ] **Environment Audit:** 
    - Verify `google_maps_flutter` API keys are correctly injected in `AndroidManifest.xml` and `AppDelegate.swift`.
    - Validate `firebase.json` and `google-services.json` integrity.
- [ ] **Test Readiness:** Fix `flutter test` compilation errors (mocks/generated code).
- [ ] **Subscription Bridge:** Define `SubscriptionStatus` enum (Active, Trial, Inactive) to bridge existing webhook logic with the Flutter app.
- **Success Criteria:** 
    - `flutter test` executes with 0 compilation errors.
    - `flutter build apk --debug` succeeds.

---

## Phase 1: Authentication & Critical Routing (P1)
**Goal:** Fix the broken entry points and the "hidden" `/join-family` bug.

- [ ] **The `/join-family` Exception:** 
    - Move logic from "Notes" to core routing. 
    - Ensure deep links to join a family correctly sequence with the auth onboarding flow (Redirect to login -> Return to join).
- [ ] **Auth State Hardening:** Transition Google Sign-In to native platform flow to eliminate "missing initial state" errors.
- **Success Criteria:** 
    - Manual Test: Deep-link to `/join-family` while logged out -> Redirects to login -> Authenticates -> Correctly lands on Join screen.

---

## Phase 2: Map Interaction & Gesture Ownership
**Goal:** Fix the conflict between nested scroll views and MapView gestures.

- [ ] **Gesture Arena Management:** Implement explicit gesture ownership for the Google Map to prevent the parent `NavShell` or `PageView` from hijacking pans and zooms.
- [ ] **Success Criteria:** 
    - Physical Device Verification: Smooth 1:1 finger tracking; pinch-zoom scale works without triggering vertical page scrolling.

---

## Phase 3: Geofence Drawing & Reliability Fallback
**Goal:** Ensure users can create geofences even when external APIs (Places) are unstable.

- [ ] **Tap-to-Place Drawing:** Implement long-press/tap-to-drop pin on the map as the primary fallback for geofence creation.
- [ ] **Search Integration:** Fix the broken Places search flow (API key/restriction path).
- **Success Criteria:** 
    - User can successfully create a geofence by manually tapping the map, bypassing the search bar entirely.

---

## Phase 4: Targeted Theme Refactor (Scoped)
**Goal:** Modernize UI tokens without creating project-wide merge conflicts.

- [ ] **Scoped Refactor:** Apply new theme tokens ONLY to the 5 screens being touched in this plan: Auth, Map, Invite, Geofence, and Onboarding.
- [ ] **Tokenization:** Replace hardcoded hex values with `Theme.of(context).colorScheme` references.
- **Success Criteria:** 
    - Visual Audit: Light mode is "genuinely light" and readable on the 5 modified screens.
    - Zero regressions in layout on non-refactored screens.

---

## Phase 5: System Integration & Final Verification
**Goal:** Confirm the "whole app" works as a unified system.

- [ ] **System Walkthrough:** Signup -> Create Family -> Invite Member -> Set Geofence -> Trigger Geofence.
- [ ] **Backend Alignment:** Audit `firestore.rules` for the family structure created in previous phases.
- **Success Criteria:** 
    - 0 P1/P2 bugs remaining.
    - App passes full walkthrough without crash or navigation loop.

---

## Deferred (Next Sprint)
- Full Stripe/Billing integration.
- Full-app Theme/Design System migration.
- CI/CD Pipeline (GitHub Actions).
