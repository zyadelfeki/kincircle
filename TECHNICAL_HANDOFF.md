# KinCircle: Technical Handoff & Production Checklist

## Project Status
The KinCircle MVP is code-complete. This document provides the final technical steps required to configure the environment, perform quality assurance, and prepare the application for launch on the Google Play Store and Apple App Store.

## Step 1: Google Maps API Key Configuration
The app's core map functionality will not work until a Google Maps API key is generated and correctly configured.

### A. Getting the API Key
1. Navigate to [Google Cloud Console](https://console.cloud.google.com)
2. Create/Select Project: Create a new project or select the existing one for KinCircle
3. Enable APIs: In the "APIs & Services" > "Library" section, search for and enable:
   - Maps SDK for Android
   - Maps SDK for iOS
4. Create Credentials: Go to "APIs & Services" > "Credentials"
   - Click "Create Credentials" -> "API Key"
   - Copy the new key
5. Restrict Key (Highly Recommended):
   - Application restrictions: Add the Android package name and iOS bundle ID
   - API restrictions: Restrict to only the enabled APIs

### B. Android Configuration
File: `android/app/src/main/AndroidManifest.xml`
```xml
<application ...>
    <meta-data 
        android:name="com.google.android.geo.API_KEY"
        android:value="YOUR_API_KEY_HERE"/>
    ...
</application>
```

### C. iOS Configuration
File: `ios/Runner/AppDelegate.swift`
```swift
import UIKit
import Flutter
import GoogleMaps

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GMSServices.provideAPIKey("YOUR_API_KEY_HERE")
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
```

Add Location Permissions in `ios/Runner/Info.plist`:
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>This app needs access to your location to show you on the family map.</string>
<key>NSLocationAlwaysUsageDescription</key>
<string>This app needs background access to your location for real-time tracking and safety features like Geofencing.</string>
```

## Step 2: Firestore Security Rules
Deploy these security rules to your Firestore database to protect user data and enforce privacy controls.

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // --- USERS COLLECTION ---
    match /users/{userId} {
      // Users can read and write their own document
      allow read, write: if request.auth != null && request.auth.uid == userId;

      // Family members can read location data ONLY if invisibleMode is false
      allow get: if isFamilyMember(userId) && resource.data.invisibleMode == false;
    }

    // --- FAMILIES COLLECTION ---
    match /families/{familyId} {
      // Only members can read the family doc
      allow get: if request.auth != null && isFamilyMemberOfFamily(familyId);
      // Only the admin can update/delete the family doc
      allow update, delete: if request.auth != null && isFamilyAdmin(familyId);
      // Any authenticated user can create a family (on first setup)
      allow create: if request.auth != null;
    }

    // --- HELPER FUNCTIONS ---
    function isFamilyMember(targetUserId) {
      let familyId = get(/databases/$(database)/documents/users/$(targetUserId)).data.currentFamilyId;
      return isFamilyMemberOfFamily(familyId);
    }

    function isFamilyMemberOfFamily(familyId) {
      return request.auth != null &&
             exists(/databases/$(database)/documents/families/$(familyId)) &&
             request.auth.uid in get(/databases/$(database)/documents/families/$(familyId)).data.members;
    }

    function isFamilyAdmin(familyId) {
      return request.auth != null &&
             exists(/databases/$(database)/documents/families/$(familyId)) &&
             request.auth.uid == get(/databases/$(database)/documents/families/$(familyId)).data.adminId;
    }
  }
}
```

## Step 3: Final QA Testing Checklist
This checklist must be completed on both a real Android device and a real iPhone before launch.

### Authentication & User Management
- [ ] Sign up with email/password
- [ ] Sign up/in with Google
- [ ] Sign up/in with Apple (iOS only)
- [ ] Password reset flow works correctly
- [ ] User profile can be updated
- [ ] Account deletion works properly

### Location & Map Features
- [ ] Location permission request works correctly
- [ ] Map shows user's current location (blue dot)
- [ ] Family members appear as markers on the map
- [ ] Marker info windows show correct user information
- [ ] Location updates in real-time
- [ ] Invisible mode works correctly

### Family Management
- [ ] Family creation works
- [ ] Family member invitations work
- [ ] Member removal works
- [ ] Family settings can be updated
- [ ] Admin privileges work correctly

### Error Handling & Edge Cases
- [ ] App handles no internet connection gracefully
- [ ] Location permission denied shows appropriate message
- [ ] Invalid family ID shows appropriate message
- [ ] App handles background/foreground transitions correctly
- [ ] Battery optimization doesn't break location updates

### Performance
- [ ] App launches in under 3 seconds
- [ ] Map loads quickly
- [ ] Location updates don't cause lag
- [ ] Memory usage stays within limits
- [ ] Battery drain is reasonable

## Step 4: Production Deployment Checklist

### Android
- [ ] Generate signed APK/Bundle
- [ ] Configure ProGuard rules
- [ ] Test on multiple Android versions
- [ ] Prepare store listing materials
- [ ] Configure Firebase App Distribution

### iOS
- [ ] Configure certificates and provisioning
- [ ] Archive and export IPA
- [ ] Test on multiple iOS versions
- [ ] Prepare App Store materials
- [ ] Configure TestFlight

### Final Steps
- [ ] Update privacy policy
- [ ] Prepare app store screenshots
- [ ] Write app store descriptions
- [ ] Set up crash reporting
- [ ] Configure analytics

## Support & Maintenance
- Monitor Firebase Console for:
  - Crash reports
  - Performance metrics
  - User analytics
  - Security alerts

- Regular maintenance tasks:
  - Update dependencies
  - Review security rules
  - Monitor API usage
  - Check error logs

## Contact
For technical support or questions, contact:
[Your Contact Information]

## Final Deployment Workflow

Follow these manual steps to take KinCircle from the repository you've just received to a live listing on both app stores.

1. **Developer Accounts**  
   • Enroll in the Apple Developer Program and Google Play Developer Console using the organization's legal entity.  
   • Add at least one technical and one business contact to each account.

2. **Store Listing Preparation**  
   • Create the app record in App Store Connect and Google Play Console.  
   • Upload screenshots, privacy policy URL, age ratings, and marketing copy.  
   • Configure app permissions (Location, Background Location, Notifications, etc.).

3. **Production Signing Assets**  
   • **Android:** Generate a production keystore (`.jks`) and note the alias & passwords.  
   • **iOS:** Generate a Distribution Certificate, App Store Provisioning Profile, & corresponding `.p12` export.  
   • Store all signing artifacts in a secure secrets manager (e.g., GitHub Actions Secrets, Bitrise Vault, or 1Password).  
   • Update `fastlane/.env` or CI variables so Fastlane can access them during builds.

4. **Environment Variables**  
   • Copy `env.production.template` → `.env.production` and fill in real keys (`MAPS_API_KEY`, `FIREBASE_API_KEY`, etc.).  
   • In CI/CD, add the same keys to the runner's secret store so Fastlane lanes can read them at build time.

5. **Automated Build & Upload**  
   • Run `cd ios && bundle exec fastlane release` to archive, sign, and upload the iOS build to App Store Connect.  
   • Run `cd android && bundle exec fastlane release` to bundle, sign, and upload the Android build to Google Play (Production track).  
   • Verify the build appears in each console and submit for review.

6. **Post-Launch Checklist**  
   • Turn on Crashlytics & Performance Monitoring dashboards.  
   • Set up App Store / Play Store in-app events (promos).  
   • Monitor first-day crash-free sessions and retention.

> Once these steps are complete and the stores approve the binaries, KinCircle will be publicly available for families worldwide. 
 
## Android Release Keystore & Signing (Production)

Follow these steps to generate and use a secure production keystore for Android release builds.

### 1) Generate the keystore (one-time)

Requires Java JDK (keytool). On Windows, keytool is bundled with Java and typically located in `C:\\Program Files\\Java\\<jdk>\\bin`.

Command (PowerShell):

```powershell
& "C:\\Program Files\\Java\\jdk-21\\bin\\keytool.exe" -genkeypair -v `
  -keystore android/app/keystore/kin_release.keystore `
  -alias kinRelease `
  -keyalg RSA -keysize 2048 -validity 36500 `
  -dname "CN=KinCircle, OU=Mobile, O=KinCircle, L=Cairo, S=Cairo, C=EG"
```

You will be prompted for passwords; choose strong ones and store them in a secure password manager.

### 2) Create android/key.properties (DO NOT COMMIT)

File: `android/key.properties`

```properties
storeFile=android/app/keystore/kin_release.keystore
storePassword=YOUR_STORE_PASSWORD
keyAlias=kinRelease
keyPassword=YOUR_KEY_PASSWORD
```

This file is gitignored and read by Gradle at build time.

### 3) Gradle signing config (already wired)

File: `android/app/build.gradle.kts` loads `android/key.properties` and applies the `release` signing config automatically:

- If `key.properties` exists and is valid, release builds are signed with the production keystore.
- If not present (e.g., on a new developer machine), it falls back to the debug signing to keep local builds unblocked.

### 4) Build a signed release APK/AAB

APK (ARM64 example):

```powershell
flutter build apk --release --target-platform=android-arm64
```

AAB (recommended for Play Store):

```powershell
flutter build appbundle --release
```

Artifacts are written to `build\\app\\outputs\\flutter-apk\\app-release.apk` or `build\\app\\outputs\\bundle\\release\\app-release.aab`.

### 5) Security & backup

- Store `kin_release.keystore` and the passwords in a secure vault (1Password, Bitwarden, or your CI/CD secret store).
- Never commit `key.properties` or the keystore to git.
- Consider setting up Play App Signing for additional protection and key management.