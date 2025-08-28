# Vertex AI POC Runbook

A concise, step-by-step checklist to run the Smart Alerts ML POC end-to-end.

## 1) Generate and Upload Synthetic Data

- From `functions/`:

```bash
node ./src/scripts/generate_synthetic_data.js
node ./src/scripts/upload_synthetic_data.js --project <YOUR_PROJECT_ID> --file src/scripts/test_data.json
```

- Verify Firestore → BigQuery export is enabled and rows appear in `firestore_export`.

## 2) Train and Deploy the Model (Vertex AI)

- Follow `docs/VERTEX_AI_TRAINING_GUIDE.md`:
  - Create dataset from BigQuery table
  - Train AutoML classification model
  - Deploy to an endpoint
  - Capture `MODEL_ENDPOINT_ID`

## 3) Configure Cloud Functions

- Deploy or update functions with env:

```bash
# Example using gcloud; adapt if using firebase-tools
# gcloud functions deploy getAnomalyScore --set-env-vars MODEL_ENDPOINT_ID=<ID>
# gcloud functions deploy onUserLocationChange --set-env-vars MODEL_ENDPOINT_ID=<ID>
```

## 4) Set Feature Flags and Threshold

- Create/update Firestore doc `configuration/ai_settings`:
  - `ml_alerts_enabled: true`
  - `anomaly_threshold: 0.85`

## 5) Validate End-to-End

- Move a test user to create `location_events` (or update a user’s `lastKnownLocation`).
- Confirm `alerts` documents appear when ML score exceeds the threshold.
- App shows alerts via top MaterialBanner.

## 6) Weekly Retraining (Optional)

- Use `docs/RETRAIN_SCHEDULER_SETUP.md` to set a weekly Cloud Scheduler job for `retrainAnomalyModel`.
