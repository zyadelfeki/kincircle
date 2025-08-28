# KinCircle

KinCircle is a Flutter app that delivers AI-powered Smart Alerts for families: get notified about what’s unusual, not what’s routine.

## Where to start (engineers)

- Final build command: see `HOW_TO_BUILD.md` (single AAB command + prerequisites)
- Vertex AI POC runbook: `docs/VERTEX_AI_POC_RUNBOOK.md`
- Vertex AI training guide: `docs/VERTEX_AI_TRAINING_GUIDE.md`
- Weekly retraining setup: `docs/RETRAIN_SCHEDULER_SETUP.md`
- Cost monitoring during beta: `docs/CLOUD_COST_MONITORING_GUIDE.md`
- Privacy & consent: `docs/PRIVACY_POLICY_V2.md` and in-app `Smart Alerts Consent`

## Development

- Flutter stable; analyze/tests should pass cleanly.
- Remote Config controls: smart_alerts_enabled, ml_alerts_enabled, anomaly_threshold (see `functions/src/scripts/seed_ai_settings.js`).

## License

Copyright © KinCircle.
