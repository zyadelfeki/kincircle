# KinCircle – End-to-End Technical Story

This document narrates the project from initial concept to the current feature-complete milestone. It details system architecture, design decisions, feature implementations, file locations, tooling, configuration, and operational considerations. It contains no source code—only descriptions of approaches and files involved.

## 1. Product vision and objectives

- Core idea: A calm, family-first safety and coordination app—low-noise alerts, shared presence, simple invites, and respectful privacy.

- Primary goals:
  - Reliable family graph (create, invite, accept), shared locations with geofence “safe zones,” and lightweight alerts.
  - Calm Support: self-serve help, quick escalation, and predictable response.
  - Premium path: a tasteful paywall, contextual gating, and reactive “Pro Theme.”
  - Operational reliability: Firebase-first, minimal infrastructure, observability.

## 2. High-level architecture

- Client: Flutter/Dart app targeting Android and iOS. Material 3 and Provider for state.

- Backend: Firebase Auth, Firestore, Functions, Storage, Remote Config, Crashlytics, Dynamic Links.

- Optional ML/Analytics: Vertex AI via Cloud Functions, BigQuery sink for labeled feedback.

- Payments: In-app purchases using native store billing; entitlements reflected in Firestore.

- Email: SendGrid REST via in-app client with Cloud Functions fallback and secrets.

## 3. Major milestones (chronology)

- Stabilization and rebrand: crash fixes, Firestore precondition UI, dependency hygiene. Release builds verified.

- Branding consolidation: common logo, Trust Blue theme, UI de-noise, app launcher modernized.

- Asset pipeline: SVG finalization, references updated, generator/tests, removal of legacy assets.

- Build repair: Kotlin/AGP alignment, Gradle/analyzer cleanup.

- Feature wave:
  - Help Center with search and per-FAQ helpfulness, inline contact form, and ticket creation.
  - Pro Theme: deep charcoal/navy base with teal/gold accents; auto-reacts to subscription.
  - Transactional email services: Welcome and Password Reset via SendGrid with callable fallback.
  - Paywall: landing-style page, iconography, polished copy, contextual gating, and native IAP wiring.
- Finalization: Forgot Password flow, Welcome email on sign-up, release build for QA.

## 4. Core features and how they’re implemented

### 4.1 Family graph & invites

- Family creation, invite sending, accepting, and membership checks centralized in a Firestore service.

- Email invites via SendGrid REST with a callable Cloud Function fallback; deep links route to accept flows.

- Files:
  - `lib/services/firestore_service.dart` – family operations, helpers (e.g., get current family ID).
  - `lib/screens/family/create_family_screen.dart` – family creation UI.
  - `lib/screens/family/invite_screen.dart` – send invite and link/QR; now gated by plan.
  - `lib/screens/family/share_invite_screen.dart` – share flows.
  - `lib/screens/family/accept_invite_screen.dart` – acceptance entry.
  - Cloud Function: `functions/src/index.ts` (callable `sendInviteEmail`).

### 4.2 Location and safe zones

- Users’ last known location written to Firestore; normalized to `location_events` for alert evaluation.

- Safe zones (geofences) are created with a place search and preview; rule-based alerts trigger upon boundary/time window breaches.

- Files:
  - `lib/screens/geofencing/add_geofence_screen.dart` – place search, map preview, save safe zones. Now gated by plan.
  - Cloud Functions in `functions/src/index.ts` – `normalizeLocationEvent`, `checkRuleBasedAlerts`.

### 4.3 Alerts & driver safety

- Alerts list with filters; driver safety hub available as a gated Pro feature.

- Files:
  - `lib/screens/alerts/alerts_screen.dart` – alerts feed.
  - `lib/screens/driving/driver_safety_hub_screen.dart` – hub entry (gated via Pro checks).
  - `lib/screens/dashboard/dashboard_screen.dart` – top-level gating for Driver Safety and SOS actions.

### 4.4 Calm Support framework

- Help Center loads a Markdown FAQ and renders sections/items; search filters across titles/answers.

- Each FAQ shows a “Was this helpful?” interaction; a “No” reveals a compact inline contact form.

- Full contact form supports name/email/subject/message and optional screenshot upload to Storage.

- Ticket creation writes to Firestore with metadata and returns a ticket number.

- Files:
  - `lib/screens/support/help_screen.dart` – searchable help, helpfulness chips, `_InlineContactForm`, and full `_ContactSupportForm`.
  - `lib/services/support_ticket_service.dart` – upload screenshot to Storage; create `support_tickets` Firestore doc.
  - Asset source: `docs/FAQ.md` – rendered content.

### 4.5 Pro Theme (reactive)

- Premium theme palette applied across light/dark with accent updates; toggles automatically when `users/{uid}.isPro` changes.

- A controller syncs local state with Firestore and persists user preference for theme mode and Pro.

- Files:
  - `lib/utils/theme.dart` – theme builder and palette tuning (teal/gold accents, deep navy backgrounds).
  - `lib/services/theme_controller.dart` – persistent theme mode; Firestore subscription to `isPro`.
  - `lib/main.dart` – rebuilds themes when `isPro` changes; starts Firestore sync.

### 4.6 Paywall and contextual gating

- In-app paywall showcases benefits, pricing (monthly/annual), social proof, and FAQs.

- Contextual gating: Upsell intercepts when free users hit Pro-only paths (invites member limit, safe zone limit, Driver Safety, SOS).

- Files:
  - `lib/screens/account/pro_paywall_screen.dart` – landing-style paywall with CTA wired to IAP.
  - `lib/services/pro_gating_service.dart` – centralized gating checks and navigation to paywall.
  - `lib/screens/family/invite_screen.dart` – member limit gate before sending invites.
  - `lib/screens/geofencing/add_geofence_screen.dart` – safe zone limit gate before saving.
  - `lib/screens/dashboard/dashboard_screen.dart` – gates Driver Safety button and SOS FAB.
  - Routes registered in `lib/main.dart` (`'/paywall'`).

### 4.7 In-app purchases and entitlements

- Native billing handled via a purchase service querying `pro_monthly` and `pro_annual` products.

- On purchase success/restoration, entitlements are recorded in Firestore under `users/{uid}.isPro=true` with a `proSince` timestamp.

- Theme auto-switch reacts immediately due to the Firestore listener in the theme controller.

- Files:
  - `lib/services/purchase_service.dart` – product queries, purchase transactions, entitlement updates.
  - `lib/services/theme_controller.dart` – listens for `isPro` changes.

### 4.8 Transactional email and SendGrid

- SendGrid used for transactional messages (Welcome, Password Reset), with a Cloud Functions fallback where relevant.

- Emails are composed and sent via a local SendGrid client if configured via dart-defines.

- Files:
  - `lib/services/sendgrid_service.dart` – in-app REST client; `isConfigured` indicator.
  - `lib/services/auth_mail_service.dart` – high-level transactional emails (Welcome, Password Reset).
  - `functions/src/index.ts` – callable `sendInviteEmail`; added callable `generatePasswordResetLink`.

### 4.9 Authentication flows

- Email/password, Google, and Apple supported. On sign-up, user profiles are ensured in Firestore.

- Welcome email automatically sent right after a successful sign-up when SendGrid is configured.

- “Forgot password?” button prompts for email, generates a reset link via callable, and sends branded email; falls back to Firebase’s default reset email when necessary.

- Files:
  - `lib/services/auth_service.dart` – sign up/in flows; document initialization; friendly error mapping.
  - `lib/screens/auth/login_signup_screen.dart` – toggled view for login/registration; Welcome email wire-up; Forgot Password dialog and reset flow.

### 4.10 Dynamic Links & App Links

- Deep links support invite acceptance and onboarding routing.

- Files:
  - `lib/services/dynamic_link_service.dart` and `lib/services/app_links_dynamic_link_service.dart` – abstraction and platform handling.
  - Cloud Function: invite email includes deep link using the links host (e.g., `links.kincircle.app`).

## 5. Firebase backend: functions and data flow

- Functions (`functions/src/index.ts`):
  - `sendInviteEmail` – SendGrid invite email with deep link.
  - `getAnomalyScore` – optional Vertex AI callable for anomalies (prototype).
  - `onUserLocationChange` – triggers ML checks optionally and writes alerts.
  - `checkRuleBasedAlerts` – rule-based alerts for geofences and school hours.
  - `onAlertFeedbackCreate` – writes feedback rows to BigQuery.
  - `normalizeLocationEvent` – writes `location_events` when user location changes.
  - `retrainAnomalyModel` – weekly Pub/Sub triggered model retrain (prototype).
  - `generatePasswordResetLink` – returns a password reset link for branded email without revealing account existence.

## 6. Storage, rules, and data

- Firestore collections referenced (names only): `users`, `families`, `invites`, `alerts`, `geofences`, `location_events`, `support_tickets`, `alert_feedback`, `configuration`.

- Storage buckets used for support attachments under a scoped folder (by ticket).

- Indexes: `firestore.indexes.json` configured for known query patterns.

- Security: app writes to own user documents and family-scoped documents with rule checks; support tickets allowed for authenticated users; attachments checked by auth and path prefix.

## 7. UI and theming

- Material 3 with a consistent typographic scale and Inter through Google Fonts.

- Pro palette: teal as primary, gold as secondary, deep navy for surfaces; careful on-surface contrast adjustments.

- Branding cleanup: central SVG logo used across launcher and header assets; noisy visual elements removed.

- Files:
  - `lib/utils/theme.dart` – theme construction and Pro accents.
  - `assets/icon/kin_arc_final.svg` – primary logo asset.

## 8. Gating strategy

- Soft paywalls at action points: invites, safe zone creation, Driver Safety, SOS.

- Clear copy: limit explanations, benefits, and direct path to upgrade via paywall.

- Entitlements synchronized by Firestore; local state listens and updates instantly.

- Files:
  - `lib/services/pro_gating_service.dart` – centralized logic and helpers.

## 9. Email and notifications

- Transactional path uses SendGrid when configured by dart-defines: `SENDGRID_API_KEY`, `FROM_EMAIL`.

- Welcome email: sent immediately after sign-up at the UI layer.

- Password reset: dialog collects email; callable generates a reset link; branded email sent; fallback to Firebase default email.

- Files:
  - `lib/services/auth_mail_service.dart`, `lib/services/sendgrid_service.dart`, `lib/services/password_reset_service.dart`.

## 10. Payments and SKUs

- Product IDs expected: `pro_monthly`, `pro_annual` in Google Play Console and App Store Connect.

- Purchases trigger entitlement updates via the purchase service; Firestore listener switches theme and unlocks gates.

- Files:
  - `lib/services/purchase_service.dart`.

## 11. Diagnostics and observability

- Crash reporting via Crashlytics; remote feature toggles via Remote Config (e.g., ML alerts on/off, thresholds via config documents).

- In-app Diagnostics screen to show environment state when needed.

- Files:
  - `lib/screens/support/diagnostics_screen.dart`.

## 12. Performance and stability work

- Scrollable overflows and legibility issues addressed; unified paddings and variants.

- Android build modernization: AGP/Kotlin alignment; eliminated analyzer warnings where feasible.

- Asset and icon generation refreshed and referenced consistently.

## 13. Project structure (key areas)

- Root files:
  - `pubspec.yaml` – dependencies; asset declarations; launcher config.
  - `package.json` (for Functions) – Node/TS dependencies.
  - `README.md`, `HOW_TO_BUILD.md`, `BUILD_INSTRUCTIONS.md`, `LAUNCH_CHECKLIST*.md` – process docs.
- App code: `lib/`
  - Auth: `screens/auth/*`, `services/auth_service.dart`.
  - Dashboard & features: `screens/dashboard/*`, `screens/geofencing/*`, `screens/driving/*`, `screens/alerts/*`.
  - Support: `screens/support/*`, `services/support_ticket_service.dart`.
  - Account & paywall: `screens/account/*`, `services/purchase_service.dart`, `services/pro_gating_service.dart`.
  - Theme & state: `utils/theme.dart`, `services/theme_controller.dart`.
  - Email: `services/auth_mail_service.dart`, `services/sendgrid_service.dart`, `services/password_reset_service.dart`.
  - Data: `services/firestore_service.dart`.
- Firebase Functions: `functions/src/index.ts` and helper scripts in `functions/src/scripts/*`.
- Android and iOS folders: platform setup, Gradle/Xcode configs.
- Assets: `assets/`, `docs/FAQ.md`.

## 14. Configuration and secrets

- Required dart-defines for transactional email:
  - `SENDGRID_API_KEY`
  - `FROM_EMAIL`
- Store configuration:
  - Play/App Store product IDs: `pro_monthly`, `pro_annual`.
  - SHA-1/SHA-256 configured in Firebase for Android sign-in providers.
- Cloud Functions environment:
  - `SENDGRID_API_KEY` secret.
  - Optional Vertex AI and BigQuery variables for ML features.

## 15. Security and privacy approach

- Minimal PII collection; user control over profile attributes.

- Support tickets include only user-supplied details and optional screenshots.

- Password reset avoids user enumeration by suppressing errors and using a callable that returns empty link when appropriate.

- Firestore rules restrict access to user-scoped and family-scoped documents.

## 16. QA checklist for this milestone

- Create account and verify Welcome email (when SendGrid configured).

- Login view → “Forgot password?” → email prompt → receive branded reset email or Firebase default.

- Invite member on Free plan → see gating and paywall; upgrade path works if SKUs configured.

- Add safe zone beyond Free limit → see gating.

- Open Driver Safety / SOS → gating behavior and paywall route.

- Toggle subscription in Firestore → theme switches instantly.

- Help Center: search, mark helpful/not helpful; submit inline and full contact forms; screenshot uploads appear in Storage; ticket documents created.

- Release build: app installs; basic flows stable.

## 17. Known limitations and follow-ups

- IAP SKUs must be live in stores for full purchase flow on real devices.

- Vertex AI anomaly detection is optional and controlled via flags; production training requires curated datasets.

- Email deliverability depends on SendGrid domain setup and sender reputation.

- Kotlin version warning suggests a future upgrade (Kotlin 2.1+) for long-term compatibility.

## 18. Outcome

- The app is feature-complete for the current scope: Calm Support, reactive Pro theme, transactional emails, contextual paywall with IAP wiring, and core family safety features stabilized. Release APK built and ready for final QA.
