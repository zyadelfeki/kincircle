# Cloud Storage Lifecycle Configuration for Data Retention

This document provides the configuration needed to set up automatic deletion of old support attachments in Firebase Cloud Storage.

## Overview

The lifecycle rule automatically deletes support attachments that are older than 12 months to comply with data retention policies and manage storage costs.

## Configuration Methods

### Method 1: Using Google Cloud Console

1. Navigate to the [Google Cloud Console](https://console.cloud.google.com/)
2. Select your project (`kincircle-ai`)
3. Go to Cloud Storage > Buckets
4. Find your Firebase Storage bucket (typically named `kincircle-ai.appspot.com`)
5. Click on the bucket name
6. Go to the "Lifecycle" tab
7. Click "Add rule"
8. Configure the rule:
   - **Rule scope**: "Limit the scope of this rule using filters"
   - **Select object conditions**: "Matches prefix"
   - **Prefix**: `support/`
   - **Action**: "Delete"
   - **Conditions**: "Age" > "365 days"
9. Click "Create"

### Method 2: Using gcloud CLI

Run the following command to create the lifecycle configuration:

```bash
# Create a lifecycle configuration file
cat > lifecycle-config.json << EOF
{
  "lifecycle": {
    "rule": [
      {
        "action": {
          "type": "Delete"
        },
        "condition": {
          "age": 365,
          "matchesPrefix": ["support/"]
        }
      }
    ]
  }
}
EOF

# Apply the lifecycle configuration to your bucket
gcloud storage buckets update gs://kincircle-ai.appspot.com --lifecycle-file=lifecycle-config.json
```

### Method 3: Using Firebase CLI

```bash
# Create a firebase storage rules file if it doesn't exist
# Then update your storage rules to include lifecycle management
firebase deploy --only storage
```

### Method 4: Using gsutil (Legacy)

```bash
# Create lifecycle configuration file
cat > lifecycle.json << EOF
{
  "lifecycle": {
    "rule": [
      {
        "action": {"type": "Delete"},
        "condition": {
          "age": 365,
          "matchesPrefix": ["support/"]
        }
      }
    ]
  }
}
EOF

# Apply the configuration
gsutil lifecycle set lifecycle.json gs://kincircle-ai.appspot.com
```

## Verification

To verify the lifecycle rule is active:

```bash
# View current lifecycle configuration
gcloud storage buckets describe gs://kincircle-ai.appspot.com --format="value(lifecycle)"

# OR using gsutil
gsutil lifecycle get gs://kincircle-ai.appspot.com
```

## What This Rule Does

- **Target**: Files in the `support/` folder (support ticket attachments)
- **Action**: Automatically delete files
- **Condition**: Files older than 365 days (12 months)
- **Scope**: Only affects objects with the `support/` prefix

## Notes

- The lifecycle rule takes effect within 24 hours of configuration
- Deleted objects cannot be recovered unless you have object versioning enabled
- This rule only affects new objects created after the rule is applied, but will also apply to existing objects
- Monitor your storage usage and costs to ensure the rule is working as expected

## Monitoring

You can monitor the effectiveness of this rule by:

1. Checking Cloud Storage metrics in the Google Cloud Console
2. Setting up Cloud Monitoring alerts for storage usage
3. Reviewing the cleanup logs created by the `dataRetentionCleanup` Cloud Function

## Related Functions

This lifecycle rule works in conjunction with the `dataRetentionCleanup` Cloud Function, which handles Firestore document cleanup on the same schedule.
