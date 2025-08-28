# KinCircle: Google Play Submission Package

This document is copy-paste ready for the Google Play Console. It includes store listing text, asset checklist, configuration answers, and a final QA checklist.

## Store Listing Content

- App Title: KinCircle: AI Family Locator
- Short Description (≤80 chars):
  Stay connected with family. Smart safety alerts and live location.
- Full Description:
  KinCircle is the AI-powered family locator designed for peace of mind. Create your family, invite loved ones, and see live updates—without the clutter. Get proactive “AI Smart Alerts” for unusual activity, plus an on-device Driver Safety mode that detects harsh events and summarizes trips.

  Why families choose KinCircle:
  - Simple, private, and reliable live location sharing
  - Fast invites (share link or QR) and instant membership updates
  - Driver Safety: start/end drives, local incident detection, clear safety reports
  - AI Smart Alerts (V2 rollout): context-aware notifications for unusual activity
  - Built with privacy in mind and a clear consent experience

  KinCircle helps families coordinate everyday life and stay safer—without getting in the way.

## Asset Checklist

- App Icon (1024×1024 PNG): `launch_kit/assets/icon_1024.png`
- Screenshots (1080×1920 or larger):
  
  - `launch_kit/screenshots/01_home.png`
  - `launch_kit/screenshots/02_invites.png`
  - `launch_kit/screenshots/03_live_map.png`
  - `launch_kit/screenshots/04_driving_mode.png`
  - `launch_kit/screenshots/05_safety_report.png`

## App Configuration Answers

- App Access: Limited access (review account provided)
  - Reviewer instructions: Use demo credentials to sign in and access all core features (create family, invites, live updates, Driver Safety).
  - Demo credentials:
    - Email: <review@kincircle.com>
    - Password: Test12345!
- Ads: No, the app does not contain ads.
- Content Rating Questionnaire:
  - Violence/Hate/Drugs/Adult content: No
  - User-generated content or user-to-user communication: Limited to invites and family membership; no public posting
  - Location: Yes, precise location for core functionality (family locating and safety). Background access may be requested for live updates.
  - Financial transactions/gambling: No
- Target Audience:
  - Primary audience: 13+
  - Not primarily targeted at children; not a kids app.
- Data Safety (summary):
  - Data collected: account info (email, name), precise location, app diagnostics/crash logs, and device identifiers (as applicable) to provide core functionality and reliability.
  - Data sharing: Not sold or shared with third parties beyond core service providers necessary to operate the app.
  - Security: Data in transit and at rest is encrypted. Planned V2 includes optional end-to-end encryption for location.
  - Data deletion: Users can request data deletion; account deletion removes associated personal data per policy.

## Final Pre-Submission QA Checklist

Perform these tests on a release build before uploading:

1. Sign up/login and create a new family; confirm dashboard loads without errors.
2. Send an invite to a second account; accept the invite; verify family membership updates live without page reloads.
3. Move device location (simulated is fine) and confirm the location event appears; check that appropriate rule-based alert/notification is generated.
4. Start and End a Driving Mode session; verify incidents (if any) appear and a Safety Report is created and readable.
5. Deep links/open app links from an invite; confirm correct in-app navigation.
6. Toggle offline/online (airplane mode) briefly; ensure app doesn’t crash and restores on network return.
7. Reboot device and re-launch; confirm the app opens crash-free and session persists.

---

Notes:

- Ensure Play Console screenshots and icon meet formatting guidelines.
- If ML “AI Smart Alerts” are enabled, validate a sample inference path; otherwise confirm flag is disabled.

