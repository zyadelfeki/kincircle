# App/Universal Links Hosting Templates

Host these at your domain for App Links (Android) and Universal Links (iOS).

## Android: .well-known/assetlinks.json

Serve at: <https://links.kincircle.app/.well-known/assetlinks.json> with content-type application/json.

```json
[
  {
    "relation": ["delegate_permission/common.handle_all_urls"],
    "target": {
      "namespace": "android_app",
      "package_name": "com.example.kincircle",
      "sha256_cert_fingerprints": [
        "REPLACE_WITH_SHA256_CERT_FINGERPRINT"
      ]
    }
  }
]
```

- Get the signing cert SHA256 fingerprint from your keystore or Play Console.

## iOS: apple-app-site-association (AASA)

Serve at: <https://links.kincircle.app/apple-app-site-association> with content-type application/json (no .json extension).

```json
{
  "applinks": {
    "apps": [],
    "details": [
      {
        "appID": "TEAMID.com.example.kincircle",
        "paths": ["/invite/*"]
      }
    ]
  }
}
```

- Replace TEAMID and bundle id to match your app.
- Ensure no redirects and correct content-type.
