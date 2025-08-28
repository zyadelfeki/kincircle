# Vertex AI Training & Deployment Guide (POC)

This guide shows how to turn the Firestore→BigQuery export table into a Vertex AI AutoML model for anomaly detection, then deploy it and capture the endpoint ID for Cloud Functions.

---

## 0. Prerequisites
1. `gcloud` CLI ≥ 466.0.0 with Vertex AI components enabled.
2. Authenticated against the **kincircle-ai** project and default region *us-central1*:
   ```bash
   gcloud config set project kincircle-ai
   gcloud config set ai/region us-central1
   ```
3. BigQuery table `kincircle_ai.firestore_export.raw_location_events` already receiving data via the Firestore → BigQuery export extension.
4. Service-account running the commands has `Vertex AI Admin` & `BigQuery DataViewer` roles.

---

## 1. Create a Vertex AI Dataset (Tabular)
```bash
# Name for the Vertex dataset
DATASET_DISPLAY_NAME="location_events_dataset"
BQ_SOURCE="bq://kincircle_ai.firestore_export.raw_location_events"

# Create the dataset from the BigQuery table
DATASET_ID=$(gcloud ai datasets create \
  --display-name="$DATASET_DISPLAY_NAME" \
  --metadata-schema-uri="gs://google-cloud-aiplatform/schema/dataset/metadata/tables_1.0.0.yaml" \
  --data-item-labels-table="$BQ_SOURCE" \
  --format="value(name)" )

echo "DATASET_ID=$DATASET_ID"
```
The CLI returns a resource name like `projects/123/locations/us-central1/datasets/456`. Save it for the next step.

---

## 2. Launch AutoML Training (Classification)
We will classify each row as **normal** or **anomalous** based on a boolean column `is_anomaly`. If you do not yet have this column, create a VIEW or add a derived field before training.

```bash
MODEL_DISPLAY_NAME="location_anomaly_automl"
TARGET_COLUMN="is_anomaly"   # bool (true = anomaly)
TRAINING_JOB_ID=$(gcloud ai tabular-datasets train-automl \
  --dataset="$DATASET_ID" \
  --target-column="$TARGET_COLUMN" \
  --display-name="$MODEL_DISPLAY_NAME" \
  --prediction-type="classification" \
  --train-budget-milli-node-hours=1000 \
  --format="value(name)" )

echo "TRAINING_JOB_ID=$TRAINING_JOB_ID"
```
The job may take ~1-2 hours. Check status:
```bash
gcloud ai jobs describe "$TRAINING_JOB_ID"
```
When the job finishes, note the **modelId** printed at the end (e.g. `1234567890123`).

---

## 3. Deploy the Model to an Endpoint
```bash
MODEL_ID="<MODEL_ID_FROM_PREVIOUS_STEP>"
ENDPOINT_DISPLAY_NAME="location_anomaly_endpoint"

# Create an endpoint
ENDPOINT_ID=$(gcloud ai endpoints create \
  --display-name "$ENDPOINT_DISPLAY_NAME" \
  --format="value(name)" )

echo "ENDPOINT_ID=$ENDPOINT_ID"

# Deploy the model
gcloud ai endpoints deploy-model "$ENDPOINT_ID" \
  --model="$MODEL_ID" \
  --display-name="anomaly-model-v1" \
  --traffic-split=0=100 \
  --min-replica-count=1 \
  --max-replica-count=1
```
Deployment completes in a few minutes. The **ENDPOINT_ID** looks like `projects/123/locations/us-central1/endpoints/789`.

Add the numeric endpoint ID (the last segment) to Runtime Config / env variable so Cloud Functions can call it:
```bash
gcloud functions deploy getAnomalyScore \   # or `functions deploy` via firebase-tools
  --update-env-vars MODEL_ENDPOINT_ID=<ENDPOINT_ID_LAST_SEGMENT>
```

---

## 4. Test the Endpoint
```bash
INSTANCE='{"user_id":"testUser123","day_of_week":2,"hour_of_day":19}'

gcloud ai endpoints predict "$ENDPOINT_ID" --json-request="{\"instances\":[$INSTANCE]}"
```
You should see a JSON response with `predicted_label` & `confidence`.

---

## 5. Clean-Up (optional)
```bash
# Delete endpoint and model if you want to avoid ongoing charges
#gcloud ai endpoints undeploy-model $ENDPOINT_ID --deployed-model-id=<DEPLOYED_MODEL_ID>
#gcloud ai endpoints delete $ENDPOINT_ID
#gcloud ai models delete $MODEL_ID
```

---

### Next Steps
* Update the Cloud Function `getAnomalyScore` ENV `MODEL_ENDPOINT_ID`.
* Turn **ml_alerts_enabled** feature flag to true in Remote Config for internal testers.
* Iterate on schema / feature engineering to improve model accuracy. 