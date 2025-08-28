# KinCircle – ML Schema V1

This document defines the initial BigQuery table schema used for training the rule-based / statistical anomaly-detection models powering **Smart Routine Alerts**.

## Dataset & Table
```
Dataset: kincircle_ai
Table  : location_events_features_v1
```

| Column Name  | Type      | Description |
|--------------|-----------|-------------|
| event_id     | STRING    | UUIDv4 generated for each location event record |
| user_id      | STRING    | Firebase Auth UID of the family member |
| timestamp    | TIMESTAMP | Event creation time in UTC |
| latitude     | FLOAT64   | Latitude portion of GeoPoint |
| longitude    | FLOAT64   | Longitude portion of GeoPoint |
| day_of_week  | INT64     | 0 = Sunday … 6 = Saturday (derived) |
| hour_of_day  | INT64     | 0-23 hour extracted from timestamp (derived) |
| minute_of_day| INT64     | (hour * 60 + minute) useful for cyclical encoding |
| geo_hash_7   | STRING    | 7-char geohash for spatial clustering |

### Partition & Clustering
* **Partitioned** by `DATE(timestamp)` to make sliding-window training efficient.
* **Clustered** by `user_id`, `day_of_week`, `hour_of_day` for faster per-user queries.

## ETL / Feature Pipeline
1. Raw `location_events` are ingested from Firestore export into BigQuery table `raw_location_events` (auto-schema).
2. A nightly scheduled query produces `location_events_features_v1` applying:
   * GeoPoint split into latitude / longitude.
   * Geohash calculation using `bqutil.hashing.ST_GEOHASH()`.
   * Date-time extraction for temporal features.
   * UUID generation via `GEN_RANDOM_UUID()`.

## Model Input
The downstream batch job exports the following feature columns to Vertex AI:
```
user_id, timestamp, latitude, longitude, day_of_week, hour_of_day, minute_of_day, geo_hash_7
```
Target label is **implicit** — the first phase is unsupervised; anomaly score thresholding handled at inference.

## Future Extensions
* Add `speed_kph` and `distance_from_home` once sensor data stream is integrated.
* Encode cyclical temporal features using sine/cosine.
* Introduce rolling statistics features (e.g., median location per 15-min slot). 