# KinCircle – Smart Alerts Public Launch Checklist

_Last updated: 2025-06-16_

## 1. Final QA Sign-Off ✅
- [ ] All critical/major bugs fixed (Crashlytics zero open issues)
- [ ] Battery drain < 5 % vs baseline (see Battery Performance Report)
- [ ] Smart Alerts precision ≥ 85 % on staging dataset
- [ ] Regression suite passed on iOS & Android (login, invites, maps, settings)
- [ ] Remote Config defaults verified (smart_alerts_enabled=true, silence_enabled=false, voice_sos_enabled=false)

## 2. App Store & Play Store Assets 📸
- [ ] Updated screenshots highlighting Smart Alerts
- [ ] "What's New" text copied from docs/MARKETING_AND_COMMS.md
- [ ] Promo video (optional) uploaded
- [ ] Age rating & privacy metadata updated

## 3. Server-Side & Cloud Checks ☁️
- [ ] Firestore security rules deployed & tested
- [ ] BigQuery dataset location_events has 30-day TTL policy
- [ ] Vertex AI quota overrides in place (see Cloud Cost Guide)
- [ ] `anomaly_threshold` confirmed at 0.9 in `configuration/ai_settings`
- [ ] All API keys present in production `.env.production` & CI secrets

## 4. Release Steps 🚀
1. **Bump version** – update `pubspec.yaml` `version:` and native build numbers.
2. **iOS**  
   ```bash
   cd ios && bundle exec fastlane release
   ```
3. **Android**  
   ```bash
   cd android && bundle exec fastlane release
   ```
4. Wait for build processing in App Store Connect & Play Console.
5. Submit for review with phased release (7-day rollout).

## 5. Post-Launch Monitoring 📊
- [ ] Crashlytics dashboard clean (< 0.5 % session crash rate)
- [ ] BigQuery / Vertex AI spend tracked daily (dashboard link)
- [ ] FCM topic `beta_testers` migrated to `smart_alerts_users` (optional)
- [ ] Customer support macro created for Smart Alerts FAQ

---
_Use this checklist as the single source of truth. All boxes must be ticked before pressing **Release to Public**._ 