terraform {
  required_version = ">= 1.5.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "Default region for resources"
  type        = string
  default     = "us-central1"
}

variable "billing_account" {
  description = "GCP billing account ID (e.g. 012345-67890A-BCDEF0)"
  type        = string
}

# Enable required APIs
resource "google_project_service" "bigquery" {
  service = "bigquery.googleapis.com"
}

resource "google_project_service" "vertex_ai" {
  service = "aiplatform.googleapis.com"
}

# BigQuery dataset for Firestore export
resource "google_bigquery_dataset" "firestore_export" {
  dataset_id = "firestore_export"
  location   = var.region
  description = "Auto-exported Firestore data from KinCircle"
}

# Temporary GCS bucket for staging data
resource "google_storage_bucket" "temp_data" {
  name          = "${var.project_id}-tmp-data"
  location      = var.region
  force_destroy = true

  uniform_bucket_level_access = true
  lifecycle_rule {
    action {
      type = "Delete"
    }
    condition {
      age = 30
    }
  }
}

# Budget alert
resource "google_billing_budget" "monthly" {
  billing_account = var.billing_account

  display_name = "KinCircle AI Budget"
  amount {
    specified_amount {
      currency_code = "USD"
      units         = 400
    }
  }
  threshold_rules {
    threshold_percent = 0.8 # 80%
  }
  budget_filter {
    projects = [format("projects/%s", var.project_id)]
  }
}

# Pub/Sub topic for weekly model retrain
resource "google_pubsub_topic" "weekly_retrain" {
  name = "weekly-model-retrain"
}

# Cloud Scheduler job to publish message weekly Sunday 03:00
resource "google_cloud_scheduler_job" "weekly_retrain_job" {
  name        = "weekly-model-retrain-job"
  description = "Kick off Vertex AI model retrain each week"
  schedule    = "0 3 * * 0" # 03:00 Sunday UTC
  time_zone   = "UTC"

  pubsub_target {
    topic_name = google_pubsub_topic.weekly_retrain.name
    data       = base64encode("retrain")
  }
} 