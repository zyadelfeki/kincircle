# KinCircle – Release Build Instructions

## Prerequisites
* Flutter SDK configured and on latest stable channel
* Xcode command-line tools (for iOS)
* Android SDK + NDK, Java 17 (for Android)
* Run `flutter pub get` before building

---

## Android – Generate Play Store App Bundle (.aab)
```bash
# Ensure signing keystore configured in android/key.properties & build.gradle
flutter build appbundle \
  --release \
  --target lib/main.dart \
  --dart-define=FLAVOR=prod
```
The resulting file will be located at:
```
build/app/outputs/bundle/release/app-release.aab
```
Upload this bundle to Google Play Console ➜ Production ➜ Create Release.

## iOS – Generate Archive (.xcarchive) & IPA
```bash
# 1. Use Flutter to trigger Xcode archive
flutter build ipa \
  --release \
  --export-options-plist=ios/Runner/ExportOptions.plist \
  --target lib/main.dart \
  --dart-define=FLAVOR=prod
```
The command will:
1. Produce an `.xcarchive` in `build/ios/archive/`.
2. Export a signed `.ipa` into `build/ios/ipa/` ready for TestFlight / App Store Connect upload.

Ensure that:
* Xcode project signing & bundle identifier are set to the App Store provisioning profile.
* Version and build numbers are bumped in `pubspec.yaml` & Xcode target settings before archiving. 