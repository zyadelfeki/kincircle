import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import {VertexAI} from '@google-cloud/vertexai';
import {BigQuery} from '@google-cloud/bigquery';

admin.initializeApp();
const db = admin.firestore();

// Initialize Vertex client
const PROJECT_ID = process.env.PROJECT_ID || 'kincircle-ai';
const LOCATION = process.env.VERTEX_LOCATION || 'us-central1';
const ENDPOINT_ID = process.env.MODEL_ENDPOINT_ID || 'REPLACE_WITH_ENDPOINT_ID';

const vertexAI = new VertexAI({project: PROJECT_ID, location: LOCATION});
const bigquery = new BigQuery();

// helper to fetch threshold
async function fetchThreshold(): Promise<number> {
  try {
    const doc = await db.collection('configuration').doc('ai_settings').get();
    const val = doc.data()?.anomaly_threshold;
    if (typeof val === 'number') return val;
  } catch (_) { /* swallow */ }
  return 0.85; // default
}

// HTTP callable to get anomaly score
export const getAnomalyScore = functions.https.onCall(async (data: any, context: any) => {
  if (!ENDPOINT_ID || ENDPOINT_ID === 'REPLACE_WITH_ENDPOINT_ID') {
    throw new functions.https.HttpsError('failed-precondition', 'Model endpoint not configured');
  }
  const event = data?.location_event;
  if (!event) {
    throw new functions.https.HttpsError('invalid-argument', 'location_event missing');
  }

  const instance = {
    user_id: event.userId,
    day_of_week: event.day_of_week,
    hour_of_day: event.hour_of_day,
  };

  try {
    const endpoint = vertexAI.endpoint(ENDPOINT_ID);
    const [prediction] = await endpoint.predict({instances: [instance]});
    /*
      AutoML tabular returns predictions like:
      {
        prediction: [
          { predicted_label: 'anomalous', confidence: 0.92 }
        ]
      }
    */
    const pred = prediction?.predictions?.[0] ?? {};
    const label = pred['predicted_label'] ?? 'normal';
    const confidence = pred['confidence'] ?? 0.0;
    const threshold = await fetchThreshold();

    return {
      is_anomaly: label === 'anomalous' && confidence > threshold,
      confidence_score: confidence,
    };
  } catch (err) {
    console.error('Vertex prediction error', err);
    throw new functions.https.HttpsError('internal', 'Prediction failed');
  }
});

// Trigger on updates to a user document
export const onUserLocationChange = functions.firestore
  .document('users/{userId}')
  .onUpdate(async (change: any, context: any) => {
    const beforeData = change.before.data();
    const afterData = change.after.data();

    // Proceed only if lastKnownLocation has changed
    if (
      !beforeData?.lastKnownLocation ||
      !afterData?.lastKnownLocation ||
      (beforeData.lastKnownLocation.latitude === afterData.lastKnownLocation.latitude &&
        beforeData.lastKnownLocation.longitude === afterData.lastKnownLocation.longitude)
    ) {
      return null;
    }

    const userId = context.params.userId as string;
  const location = afterData.lastKnownLocation as any;

    const docRef = await db.collection('location_events').add({
      userId,
      location,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Check feature-flag to decide whether to perform ML anomaly detection
    let mlEnabled = false;
    try {
      const flagDoc = await db.collection('configuration').doc('ai_settings').get();
      mlEnabled = flagDoc.data()?.ml_alerts_enabled === true;
    } catch (_) {/* ignore errors, default false */}

  if (mlEnabled) {
      if (!ENDPOINT_ID || ENDPOINT_ID === 'REPLACE_WITH_ENDPOINT_ID') {
        console.warn('ML alerts enabled but MODEL_ENDPOINT_ID is not configured; skipping prediction');
        return null;
      }
      // Build simple instance for anomaly detection
      const now = new Date();
      const instance = {
        user_id: userId,
        day_of_week: now.getDay(),
        hour_of_day: now.getHours(),
      };

      try {
        const endpoint = vertexAI.endpoint(ENDPOINT_ID);
        const [prediction] = await endpoint.predict({instances: [instance]});
        const pred = prediction?.predictions?.[0] ?? {};
        const threshold = await fetchThreshold();
  if (pred['predicted_label'] === 'anomalous' && (pred['confidence'] ?? 0) > threshold) {
          await db.collection('alerts').add({
            userId,
      message: 'AI Smart Alert: Unusual activity detected!',
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
            confidence: pred['confidence'] ?? 0,
          });
        }
      } catch (e) {
        console.error('ML prediction failed', e);
      }
    }

    return null;
  });

// --- Rule-Based Smart Alert Cloud Function ---
export const checkRuleBasedAlerts = functions.firestore
  .document('location_events/{eventId}')
  .onCreate(async (snap: any, context: any) => {
    const data = snap.data();
    if (!data) return null;

    // If ML alerts are enabled, skip rule-based alerts to avoid duplicates
    try {
      const flagDoc = await db.collection('configuration').doc('ai_settings').get();
      if (flagDoc.data()?.ml_alerts_enabled === true) {
        return null;
      }
    } catch (_) {
      // ignore and proceed with rule-based if flag cannot be read
    }

    const userId: string = data.userId;
  const location = data.location as any;
  const timestamp = data.timestamp as any;
    if (!location || !timestamp) return null;

  // Retrieve all geofences from Firestore
  const geofencesSnap = await db.collection('geofences').get();

    // --- Hard-coded School check (200m radius, weekdays 08-16h) ---
    const SCHOOL_COORD = {lat: 37.7596, lng: -122.4269};
    const distanceToSchool = haversineDistanceMeters(
      location.latitude,
      location.longitude,
      SCHOOL_COORD.lat,
      SCHOOL_COORD.lng,
    );
    const eventDate = timestamp.toDate();
    const day = eventDate.getDay(); // 0 Sunday
    const hour = eventDate.getHours();
    const isWeekday = day >= 1 && day <= 5;
    if (distanceToSchool <= 200 && isWeekday && (hour < 8 || hour >= 16)) {
      await db.collection('alerts').add({
        userId,
        message: 'Unusual activity detected at School.',
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    for (const doc of geofencesSnap.docs) {
      const gf = doc.data();
      const name = gf.name ?? doc.id;

      // Support two shapes for the geofence center:
      // 1) { center: GeoPoint }
      // 2) { lat: number, lng: number }
      let lat: number | undefined;
      let lng: number | undefined;
      if (gf.center && typeof gf.center.latitude === 'number' && typeof gf.center.longitude === 'number') {
        lat = gf.center.latitude;
        lng = gf.center.longitude;
      } else if (typeof gf.lat === 'number' && typeof gf.lng === 'number') {
        lat = gf.lat;
        lng = gf.lng;
      }

      const radius: number = gf.radiusMeters ?? gf.radius ?? 0;
      if (lat == null || lng == null || radius <= 0) {
        console.warn(`Skipping geofence ${doc.id} due to missing/invalid coordinates or radius.`);
        continue;
      }

      const distance = haversineDistanceMeters(location.latitude, location.longitude, lat, lng);
      if (distance > radius) {
        continue; // User is outside this geofence
      }

      // Time-window evaluation (defaults to 08:00-16:00 on weekdays)
      const allowedStart: number = gf.allowedStartHour ?? 8;
      const allowedEnd: number = gf.allowedEndHour ?? 16;
      const isWeekday = day >= 1 && day <= 5;
      const outsideAllowedHours = hour < allowedStart || hour >= allowedEnd;

      if (isWeekday && outsideAllowedHours) {
        await db.collection('alerts').add({
          userId,
          geofenceId: doc.id,
          message: `Unusual activity detected at ${name}.`,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
    }

    return null;
  });

function haversineDistanceMeters(
  lat1: number,
  lon1: number,
  lat2: number,
  lon2: number,
): number {
  const R = 6371000; // Radius of Earth in meters
  const toRad = (v: number) => (v * Math.PI) / 180;
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRad(lat1)) *
      Math.cos(toRad(lat2)) *
      Math.sin(dLon / 2) *
      Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

// --- Beta Program Opt-In ---
export const joinBetaProgram = functions.https.onCall(async (data: any, context: any) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }
  const uid = context.auth.uid;
  const fcmToken = data?.fcmToken as string | undefined;
  if (!fcmToken) {
    throw new functions.https.HttpsError('invalid-argument', 'fcmToken required');
  }

  try {
    // Update Firestore flag
    await db.collection('users').doc(uid).set({isBetaTester: true}, {merge: true});

    // Subscribe token to beta_testers topic
    await admin.messaging().subscribeToTopic([fcmToken], 'beta_testers');

    return {status: 'ok'};
  } catch (err) {
    console.error('joinBetaProgram failed', err);
    throw new functions.https.HttpsError('internal', 'joinBetaProgram failed');
  }
});

// --- Feedback to BigQuery ---
export const onAlertFeedbackCreate = functions.firestore
  .document('alert_feedback/{feedbackId}')
  .onCreate(async (snap: any) => {
  const data = snap.data() as any;
    if (!data) return null;

    // Compose row for BigQuery
    const row = {
      alert_id: data.alertId,
      user_id: data.userId,
      feedback: data.feedback,
      timestamp: new Date().toISOString(),
    };

    try {
      await bigquery
        .dataset('firestore_export')
        .table('alert_feedback_labeled')
        .insert(row);
      console.log('Inserted feedback row to BigQuery');
    } catch (err: any) {
      if (err && err.name === 'PartialFailureError') {
        console.error('Partial insert failure', err.errors);
      } else {
        console.error('BigQuery insert error', err);
      }
    }

    return null;
  });

// --- Normalize Location Event Cloud Function ---
export const normalizeLocationEvent = functions.firestore
  .document('users/{userId}')
  .onUpdate(async (change: any, context: any) => {
    const beforeLoc = change.before.data()?.lastKnownLocation;
    const afterLoc = change.after.data()?.lastKnownLocation;

    if (!afterLoc || (beforeLoc && beforeLoc.latitude === afterLoc.latitude && beforeLoc.longitude === afterLoc.longitude)) {
      return null; // No change in location
    }

    const userId = context.params.userId as string;
    await db.collection('location_events').add({
      userId,
      location: afterLoc,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    return null;
  });

// --- Weekly retrain Cloud Function (triggered via Pub/Sub) ---
export const retrainAnomalyModel = functions.pubsub
  .topic('weekly-model-retrain')
  .onPublish(async () => {
    console.log('Starting Vertex AI AutoML retraining job');
    try {
      const jobDisplayName = `location_anomaly_retrain_${Date.now()}`;
      const [operation] = await vertexAI.autoML().createTrainingPipeline({
        parent: vertexAI.locationPath(PROJECT_ID, LOCATION),
        trainingPipeline: {
          displayName: jobDisplayName,
          inputDataConfig: {
            datasetId: process.env.AUTO_ML_DATASET_ID,
          },
          trainingTaskDefinition:
            'gs://google-cloud-aiplatform/schema/trainingjob/definition/automl_tables_1.3.0.yaml',
          trainingTaskInputs: {
            optimizationObjective: 'MAXIMIZE_AU_ROC',
          },
          modelToUpload: {displayName: `anomaly_model_${Date.now()}`},
        },
      });
      console.log('Training job started:', operation.name);
    } catch (err) {
      console.error('Retraining failed', err);
    }
  }); 

// --- Weekly Driver Safety Score Calculation ---
// This scheduled function computes a simple 0-100 score based on anonymized weekly
// summaries uploaded by the mobile app. It does NOT read raw sensor data.
// Expected summary shape (either top-level collection or subcollection under users):
// {
//   userId?: string,              // optional when stored under users/{uid}/driver_safety_summaries
//   periodStart: Timestamp,       // start of the week (ISO week or rolling 7 days)
//   harsh_braking_count: number,  // non-negative integer
//   rapid_accel_count: number     // non-negative integer
// }
export const calculateDriverSafetyScore = functions.pubsub
  .schedule('every monday 01:00')
  .timeZone('Etc/UTC')
  .onRun(async () => {
    const now = new Date();
    const start = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
    const startTs = admin.firestore.Timestamp.fromDate(start);

    type Agg = { harsh: number; accel: number };
    const perUser: Record<string, Agg> = {};

    // Prefer collection group so apps can store summaries under users/{uid}/driver_safety_summaries
    try {
      const cgSnap = await db
        .collectionGroup('driver_safety_summaries')
        .where('periodStart', '>=', startTs)
        .get();
      for (const doc of cgSnap.docs) {
        const d: any = doc.data();
        // Derive uid either from field or from path users/{uid}/driver_safety_summaries/{id}
        const pathUid = doc.ref.parent.parent?.id;
        const uid = (d.userId as string) || pathUid;
        if (!uid) continue;
        const harsh = Number(d.harsh_braking_count || 0);
        const accel = Number(d.rapid_accel_count || 0);
        const agg = perUser[uid] || { harsh: 0, accel: 0 };
        agg.harsh += isFinite(harsh) ? harsh : 0;
        agg.accel += isFinite(accel) ? accel : 0;
        perUser[uid] = agg;
      }
    } catch (e) {
      console.warn('collectionGroup(driver_safety_summaries) query failed or unavailable', e);
    }

    // Also support a top-level collection as a fallback: driver_safety_summaries
    try {
      const topSnap = await db
        .collection('driver_safety_summaries')
        .where('periodStart', '>=', startTs)
        .get();
      for (const doc of topSnap.docs) {
        const d: any = doc.data();
        const uid = d.userId as string | undefined;
        if (!uid) continue;
        const harsh = Number(d.harsh_braking_count || 0);
        const accel = Number(d.rapid_accel_count || 0);
        const agg = perUser[uid] || { harsh: 0, accel: 0 };
        agg.harsh += isFinite(harsh) ? harsh : 0;
        agg.accel += isFinite(accel) ? accel : 0;
        perUser[uid] = agg;
      }
    } catch (e) {
      console.warn('Top-level driver_safety_summaries query failed', e);
    }

    const updates: Array<Promise<any>> = [];
    const HARSH_WEIGHT = 20; // points deducted per harsh brake
    const ACCEL_WEIGHT = 15; // points deducted per rapid acceleration

    for (const [uid, agg] of Object.entries(perUser)) {
      const raw = 100 - (agg.harsh * HARSH_WEIGHT + agg.accel * ACCEL_WEIGHT);
      const score = Math.max(0, Math.min(100, Math.round(raw)));
      updates.push(
        db.collection('users').doc(uid).set(
          {
            driverSafetyScore: score,
            driverSafetyScoreUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true },
        ),
      );
    }

    await Promise.allSettled(updates);
    console.log('calculateDriverSafetyScore updated users:', Object.keys(perUser).length);
    return null;
  });