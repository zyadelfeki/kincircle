# Dynamic Links Migration (August 2025)

Firebase Dynamic Links is deprecated and shuts down on August 25, 2025. We already isolated usage behind `DynamicLinkService`. This document outlines a low-risk path to migrate.

## Target approach

Use platform-native deep links:

- Android App Links (https + assetlinks.json)
- iOS Universal Links (https + apple-app-site-association)
- Flutter: `uni_links` for runtime handling

Why: No SaaS dependency, predictable, good UX, works with custom domains.

## High-level steps

1. Domain and hosting

- Pick a KinCircle domain (e.g., `links.kincircle.app`).
- Host `.well-known/assetlinks.json` (Android) and `apple-app-site-association` (iOS) at the domain root.

1. App config

- Android: Add intent filters for autoVerify App Links in `AndroidManifest.xml`.
- iOS: Add Associated Domains capability (`applinks:links.kincircle.app`).

1. Flutter integration

- Add dependency: `uni_links`.
- Implement `AppLinksDynamicLinkService` that:
  - Parses initial and incoming URIs (`getInitialLink`, stream) via `uni_links`.
  - Reuses the same invite parsing (`/invite/<id>`) as `FirebaseDynamicLinkService`.
- Wire up in `main.dart` by swapping the service to `AppLinksDynamicLinkService`.

1. Backward compatibility (optional)

- Keep `FirebaseDynamicLinkService` until August 25 to catch old links; prefer new links immediately.
- Log usage to track the cutoff.

1. QA checklist

- Cold start + foreground link handling for both platforms.
- Verify assetlinks.json / AASA are served with correct content-type and no redirects.
- Ensure invite IDs with special chars (URL-encoded) parse correctly.

## Deliverables

- `lib/services/dynamic_link_service.dart` (already abstracted)
- New: `lib/services/app_links_dynamic_link_service.dart`
- Android/iOS config changes as above
- `docs/DEPLOY_LINK_FILES/assetlinks.json` and `apple-app-site-association` templates
- E2E test plan

## Timing

- Implementation: ~0.5–1 day
- Platform provisioning + domain DNS: depends on access (~1–2 hours)
- QA: ~0.5 day

## Rollout

- Release with both services available; default to App Links.
- Add analytics counters for link source.
- Remove Firebase service after shutdown.

## Notes

- Keep invite path `/invite/<id>` to avoid app-side changes.
- If using a CDN or hosting platform, ensure `.well-known` paths are not altered.
