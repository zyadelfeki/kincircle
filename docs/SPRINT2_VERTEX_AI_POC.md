# Sprint 2 – Vertex AI Proof-of-Concept

This guide captures **exact CLI / console steps** to train a baseline AutoML Tabular model on BigQuery and deploy it for online prediction.  
Assumptions: you have Owner or Vertex Admin rights on the `kincircle-ai` project and `location_events_features_v1` table exists (see `ML_SCHEMA_V1.md`).

---
## 1  Create the Vertex dataset
```bash
# Set gcloud defaults
export PROJECT_ID=kincircle-ai
export REGION=us-central1
 gcloud config set project $PROJECT_ID
 gcloud config set ai/region $REGION

# Create dataset (Tabular, classification)
DATASET_DISPLAY_NAME="kc_location_events_cls"
BQ_SOURCE="bq://$PROJECT_ID.kincircle_ai.location_events_features_v1"

VERTEX_DATASET_ID=$(gcloud ai datasets create \
  --display-name=$DATASET_DISPLAY_NAME \
  --metadata-schema-uri=gs://google-cloud-aiplatform/schema/dataset/metadata/tabular_1.0.0.yaml \
  --data-source="bigquery_source={uri=$BQ_SOURCE}" \
  --format="value(name)" )
```

## 2  Launch AutoML training job
```bash
JOB_NAME="kc-automl-$(date +%Y%m%d%H%M)"
TARGET_COLUMN="label"       # assumes column with values `normal` / `anomalous`

MODEL_DISPLAY_NAME="kc_location_automl_v1"

gcloud ai jobs create $JOB_NAME \
  --display-name=$JOB_NAME \
  --region=$REGION \
  --prediction-type=classification \
  --dataset=$VERTEX_DATASET_ID \
  --target-column=$TARGET_COLUMN \
  --model-display-name=$MODEL_DISPLAY_NAME \
  --budget-milli-node-hours=1000 \
  --disable-early-stopping
```
Wait 1-3 hrs. Upon completion note the **model ID** printed by the job.

## 3  Deploy the model to an endpoint
```bash
MODEL_ID="123456789012345678"   # replace with real ID output from previous step
ENDPOINT_NAME="kc-location-endpoint"

ENDPOINT_ID=$(gcloud ai endpoints create \
  --display-name=$ENDPOINT_NAME \
  --format="value(name)" )

gcloud ai endpoints deploy-model $ENDPOINT_ID \
  --model=$MODEL_ID \
  --machine-type="n1-standard-2" \
  --traffic-split=0=100
```
The **endpoint ID** will be stored in Secret Manager (`MODEL_ENDPOINT_ID`).

---
## 4  Test prediction from the CLI
```bash
gcloud ai endpoints predict $ENDPOINT_ID \
  --json-request=<(cat <<EOF
{
  "instances": [
    {"user_id": "testUser123", "day_of_week": 1, "hour_of_day": 22}
  ]
}
EOF
)
```
A successful response returns predicted label + confidence.

---
## 5  Environment variables expected by Cloud Functions
| Secret / Var | Purpose |
|--------------|---------|
| `MODEL_ENDPOINT_ID` | Vertex endpoint numeric ID |
| `PROJECT_ID`        | GCP project (defaults to *kincircle-ai*) |
| `VERTEX_LOCATION`   | Region (e.g. *us-central1*) |

Set these with `firebase functions:config:set` or Secret Manager → Cloud Functions Runtime Env. 