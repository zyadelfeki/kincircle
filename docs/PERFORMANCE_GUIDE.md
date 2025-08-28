# Performance Guide: Finding and Fixing Jank

This guide helps you profile KinCircle with Flutter DevTools and fix slowness or frame jank.

## 1) Launch the app in profile mode

Profile mode runs with near‑release performance while keeping observability.

```bash
flutter run --profile
```

> Tip: If you need a specific device, pass `-d <deviceId>`.

## 2) Open Flutter DevTools

When the app is running, run:

```bash
flutter pub global activate devtools
flutter pub global run devtools
```

Then open the DevTools URL shown in the terminal and select your app.

## 3) Use the Performance tab

- Click Performance.
- Press Record to start a capture, then interact with the app where you see lag (e.g., switch tabs, pan the map).
- Stop the capture to analyze.

Key signals:

- Flutter frames chart: Red bars indicate missed frames.
- CPU profile: Look for functions with high inclusive time.
- Shader compilation: First‑run jank shows as shader warmup. Consider enabling Impeller (iOS/Android) on recent Flutter or prewarming shaders.

## 4) Common fixes to try first

- Move heavy work out of `build()` and animation callbacks.
- Avoid rebuilding large trees unnecessarily; use const widgets and keys.
- Use `Selector`/`Consumer` granularity with Provider so only small subtrees rebuild.
- Debounce Firestore streams if appropriate; paginate when lists get large.
- Cache images with `cached_network_image` for onboarding and avatars.
- For Google Maps:
  - Avoid rebuilding the whole `GoogleMap` widget on every state change; keep markers in a `Set` and minimize churn.
  - Batch updates and animate the camera only when necessary.

## 5) Verify improvements

Re‑record after each change. The goal is green frames with consistent timings.

## 6) Optional: app size and shader tips

- Use `--split-debug-info` and `--no-tree-shake-icons` judiciously in release builds if icons are missing.
- Consider using Impeller on supported devices to reduce shader jank.

## References

- Flutter performance best practices: <https://docs.flutter.dev/perf/best-practices>
- DevTools Performance: <https://docs.flutter.dev/tools/devtools/performance>
