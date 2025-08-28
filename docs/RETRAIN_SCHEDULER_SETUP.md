# Weekly Model Retraining – Cloud Scheduler Setup

Use these commands to trigger the `retrainAnomalyModel` Pub/Sub function weekly.

Prereqs:

- gcloud CLI authenticated and set to the correct project and region
- Pub/Sub API and Cloud Scheduler API enabled

## 1) Create the Pub/Sub Topic

```bash
PROJECT_ID="<YOUR_PROJECT_ID>"
gcloud config set project $PROJECT_ID

gcloud pubsub topics create weekly-model-retrain
```

## 2) Create the Scheduler Job (Every Sunday at 03:00)

```bash
# Timezone can be adjusted; example uses America/Los_Angeles
SCHEDULE="0 3 * * 0"  # 03:00 every Sunday (CRON)
TIMEZONE="America/Los_Angeles"

gcloud scheduler jobs create pubsub weekly-model-retrain \
  --schedule="$SCHEDULE" \
  --time-zone="$TIMEZONE" \
  --topic=weekly-model-retrain \
  --message-body="{\"trigger\":\"weekly\"}"
```

## 3) Verify

```bash
gcloud scheduler jobs run weekly-model-retrain
```

You should see logs for the Cloud Function `retrainAnomalyModel` indicating a training pipeline was started.

Notes:

- Ensure the function `retrainAnomalyModel` is deployed and has permissions to create Vertex AI training pipelines.
- Limit budgets on training jobs to control costs.

