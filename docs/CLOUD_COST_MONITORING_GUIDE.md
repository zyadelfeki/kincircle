# Google Cloud Cost Monitoring Guide

This short guide walks you through setting up a **single-pane dashboard** and budget guardrails so our Closed-Beta does not blow past the $400 / month budget.

---

## 1. Create a Custom Monitoring Dashboard

1. Sign in to **Google Cloud Console → Monitoring → Dashboards**.
2. Click **Create Dashboard** → name it `KinCircle AI Beta Cost`.  
3. Add the following widgets:

| Widget Type | Metric | Filter | Display |
|-------------|--------|--------|---------|
| Stacked Bar | `billing.gcp.bigquery.storage_cost` | Project = `kincircle-ai` | Daily cost (USD) |
| Line Chart  | `billing.gcp.bigquery.query_cost`   | same | Cumulative month-to-date |
| Line Chart  | `billing.gcp.aiplatform.training`   | same | Vertex AI training job cost |
| Line Chart  | `billing.gcp.aiplatform.prediction` | same | Online prediction cost |
| Number      | **Cloud Function invocations** `cloudfunctions.googleapis.com/function/execution_count` | Function = `getAnomalyScore` | 7-day total |

> Tip: In each chart's **View options**, turn on _Forecast_ to project end-of-month spend.

---

## 2. Budget Alert Rules (BigQuery & Vertex AI)

We already have a **$400 monthly budget** with an 80 % alert (see Terraform). Add service-specific alerts:

```bash
# 2.1  $150/month BigQuery specific alert
 gcloud billing budgets create \
   --billing-account $BILLING_ACCOUNT \
   --display-name "BigQuery Usage" \
   --budget-amount 150USD \
   --threshold-rule threshold-percent=0.8 \
   --budget-filter projects=projects/kincircle-ai,services=services/AA95-CD31-5694 # BigQuery service ID

# 2.2  $100/month Vertex AI
 gcloud billing budgets create \
   --billing-account $BILLING_ACCOUNT \
   --display-name "Vertex AI Usage" \
   --budget-amount 100USD \
   --threshold-rule threshold-percent=0.8 \
   --budget-filter projects=projects/kincircle-ai,services=services/713A-4421-0003 # Vertex AI service ID
```

Notifications default to the billing admins email; optionally add Pub/Sub channel.

---

## 3. Apply Hard Quota Caps to Vertex AI

While budgets only alert, **quota caps stop spending**. Run once:

```bash
# Limit online prediction QPS to 5 and total nodes to 1
 gcloud alpha services quota override create \
   --service=aiplatform.googleapis.com \
   --consumer=projects/$(gcloud config get-value project) \
   --dimensions="model-online-prediction-nodes=1,model-online-prediction-requests-per-minute=300" \
   --unit=1/{project}/{location}/models/{model}/onlinePrediction \
   --force

# Cap AutoML TRAIN_BUDGET_HOURS to 10 hours/week (~$60)
 gcloud alpha services quota override create \
   --service=aiplatform.googleapis.com \
   --consumer=projects/$(gcloud config get-value project) \
   --dimensions="automl-training-node-hours=40" \
   --unit=1/{project}/{location} \
   --force
```

_Revoke or raise the override later with `gcloud services quota override delete`._

---

## 4. Daily Cost Email (optional)
Use **Cloud Monitoring → Alerting → Policies**: create a policy on `billing_account/usage_cost` with **aggregation: daily sum**, threshold **> $15**, notification **email → founders@kincircle.app**.

---

**You're done!** The dashboard + budgets + hard quotas will keep beta-phase spend predictable and visible. 