# KinCircle - Build Guide

This document lists the steps to generate platform icons and build release artifacts.

## 0) Generate app icons (run when icons change)

```powershell
flutter pub get
dart run flutter_launcher_icons
```

## 1) Android

- Signed App Bundle (for Play Store):

```powershell
flutter build appbundle --release
```

- Alternative: APK for local install:

```powershell
flutter build apk --release --target-platform=android-arm64
```

## 2) iOS (from macOS)

```bash
flutter build ios --release
```

Prerequisites: Android SDK, iOS tooling (Xcode on macOS), and a configured release keystore/profiles.
