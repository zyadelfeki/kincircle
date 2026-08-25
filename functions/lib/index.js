"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.sageWeeklyRecap = exports.backfillFamilyOwnerIds = exports.dataRetentionCleanup = exports.calculateDriverSafetyScore = exports.onAlertFeedbackCreate = exports.joinBetaProgram = exports.checkRuleBasedAlerts = exports.onUserLocationChange = exports.getAnomalyScore = exports.generatePasswordResetLink = exports.sendInviteEmail = void 0;
const functions = __importStar(require("firebase-functions"));
const params_1 = require("firebase-functions/params");
const scheduler_1 = require("firebase-functions/v2/scheduler");
const admin = __importStar(require("firebase-admin"));
const vertexai_1 = require("@google-cloud/vertexai");
const bigquery_1 = require("@google-cloud/bigquery");
const mail_1 = __importDefault(require("@sendgrid/mail"));
admin.initializeApp();
const db = admin.firestore();
// Initialize Vertex client
const PROJECT_ID = process.env.PROJECT_ID || 'kincircle-ai';
const LOCATION = process.env.VERTEX_LOCATION || 'us-central1';
const ENDPOINT_ID = process.env.MODEL_ENDPOINT_ID || 'REPLACE_WITH_ENDPOINT_ID';
const vertexAI = new vertexai_1.VertexAI({ project: PROJECT_ID, location: LOCATION });
const bigquery = new bigquery_1.BigQuery();
// Configure secrets and runtime params
const SENDGRID_API_KEY = (0, params_1.defineSecret)('SENDGRID_API_KEY');
const FROM_EMAIL = process.env.FROM_EMAIL || 'no-reply@kincircle.app';
exports.sendInviteEmail = functions.runWith({ secrets: [SENDGRID_API_KEY] }).https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'Must be signed in');
    }
    const apiKey = SENDGRID_API_KEY.value();
    if (!apiKey) {
        throw new functions.https.HttpsError('failed-precondition', 'Email provider not configured');
    }
    mail_1.default.setApiKey(apiKey);
    const to = String(data?.to || '').trim();
    const inviteId = String(data?.inviteId || '').trim();
    if (!to || !inviteId) {
        throw new functions.https.HttpsError('invalid-argument', 'to and inviteId are required');
    }
    const deepLink = `https://links.kincircle.app/invite/${inviteId}`;
    const senderUid = context.auth.uid;
    try {
        await mail_1.default.send({
            to,
            from: FROM_EMAIL,
            subject: 'You\'re invited to join KinCircle',
            html: `
        <div style="font-family:Inter,Segoe UI,Arial,sans-serif;color:#0F172A">
          <h2 style="color:#2E86AB;margin:0 0 16px">KinCircle Invitation</h2>
          <p><strong>${senderUid}</strong> invited you to join their family on KinCircle.</p>
          <p>Tap the button below to accept the invitation.</p>
          <p style="margin:24px 0">
            <a href="${deepLink}" style="background:#2E86AB;color:#fff;padding:12px 16px;border-radius:8px;text-decoration:none">Accept Invite</a>
          </p>
          <p>Or open this link: <a href="${deepLink}">${deepLink}</a></p>
        </div>
      `,
        });
        return { status: 'sent' };
    }
    catch (e) {
        console.error('sendInviteEmail failed', e);
        throw new functions.https.HttpsError('internal', 'Failed to send email');
    }
});
// --- Generate Password Reset Link (callable) ---
// Allows the client to request a password reset link without revealing
// whether the email exists (we return an empty link on errors).
exports.generatePasswordResetLink = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'Must be signed in');
    }
    const email = String(data?.email || '').trim();
    if (!email) {
        throw new functions.https.HttpsError('invalid-argument', 'email required');
    }
    try {
        const link = await admin.auth().generatePasswordResetLink(email);
        return { resetLink: link };
    }
    catch (err) {
        // Intentionally do not leak whether the user exists
        console.warn('generatePasswordResetLink error (suppressed):', err);
        return { resetLink: '' };
    }
});
// helper to fetch threshold
async function fetchThreshold() {
    try {
        const doc = await db.collection('configuration').doc('ai_settings').get();
        const val = doc.data()?.anomaly_threshold;
        if (typeof val === 'number')
            return val;
    }
    catch (_) { /* swallow */ }
    return 0.85; // default
}
async function resolveAlertIdentity(userId) {
    const fallback = {
        triggeredByUid: userId,
        triggeredByName: 'Family member',
    };
    try {
        const userDoc = await db.collection('users').doc(userId).get();
        const data = userDoc.data() ?? {};
        const displayName = String(data.displayName ?? '').trim();
        const email = String(data.email ?? '').trim();
        const inferredFromEmail = email.includes('@') ? email.split('@')[0].trim() : '';
        const familyId = String(data.currentFamilyId ?? '').trim();
        return {
            triggeredByUid: userId,
            triggeredByName: displayName || inferredFromEmail || 'Family member',
            familyId: familyId || undefined,
        };
    }
    catch (err) {
        console.warn('resolveAlertIdentity failed', err);
        return fallback;
    }
}
// HTTP callable to get anomaly score
exports.getAnomalyScore = functions.https.onCall(async (data, context) => {
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
        const [prediction] = await endpoint.predict({ instances: [instance] });
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
    }
    catch (err) {
        console.error('Vertex prediction error', err);
        throw new functions.https.HttpsError('internal', 'Prediction failed');
    }
});
// Trigger on updates to a user document
exports.onUserLocationChange = functions.firestore
    .document('users/{userId}')
    .onUpdate(async (change, context) => {
    const beforeData = change.before.data();
    const afterData = change.after.data();
    // Proceed only if lastKnownLocation has changed
    if (!beforeData?.lastKnownLocation ||
        !afterData?.lastKnownLocation ||
        (beforeData.lastKnownLocation.latitude === afterData.lastKnownLocation.latitude &&
            beforeData.lastKnownLocation.longitude === afterData.lastKnownLocation.longitude)) {
        return null;
    }
    const userId = context.params.userId;
    // Check feature-flag to decide whether to perform ML anomaly detection
    let mlEnabled = false;
    try {
        const flagDoc = await db.collection('configuration').doc('ai_settings').get();
        mlEnabled = flagDoc.data()?.ml_alerts_enabled === true;
    }
    catch (_) { /* ignore errors, default false */ }
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
            const identity = await resolveAlertIdentity(userId);
            const endpoint = vertexAI.endpoint(ENDPOINT_ID);
            const [prediction] = await endpoint.predict({ instances: [instance] });
            const pred = prediction?.predictions?.[0] ?? {};
            const threshold = await fetchThreshold();
            if (pred['predicted_label'] === 'anomalous' && (pred['confidence'] ?? 0) > threshold) {
                await db.collection('alerts').add({
                    userId,
                    familyId: identity.familyId ?? null,
                    triggeredByUid: identity.triggeredByUid,
                    triggeredByName: identity.triggeredByName,
                    title: `${identity.triggeredByName} unusual activity detected`,
                    message: 'AI Smart Alert: Unusual activity detected!',
                    timestamp: admin.firestore.FieldValue.serverTimestamp(),
                    confidence: pred['confidence'] ?? 0,
                    type: 'anomaly',
                    seen: false,
                });
            }
        }
        catch (e) {
            console.error('ML prediction failed', e);
        }
    }
    return null;
});
// --- Rule-Based Smart Alert Cloud Function ---
exports.checkRuleBasedAlerts = functions.firestore
    .document('users/{userId}')
    .onUpdate(async (change, context) => {
    const beforeData = change.before.data();
    const afterData = change.after.data();
    // Proceed only if lastKnownLocation has changed
    if (!beforeData?.lastKnownLocation ||
        !afterData?.lastKnownLocation ||
        (beforeData.lastKnownLocation.latitude === afterData.lastKnownLocation.latitude &&
            beforeData.lastKnownLocation.longitude === afterData.lastKnownLocation.longitude)) {
        return null;
    }
    // If ML alerts are enabled, skip rule-based alerts to avoid duplicates
    try {
        const flagDoc = await db.collection('configuration').doc('ai_settings').get();
        if (flagDoc.data()?.ml_alerts_enabled === true) {
            return null;
        }
    }
    catch (_) {
        // ignore and proceed with rule-based if flag cannot be read
    }
    const userId = context.params.userId;
    const location = afterData.lastKnownLocation;
    if (!location)
        return null;
    const identity = await resolveAlertIdentity(userId);
    const eventDate = new Date();
    const day = eventDate.getDay();
    const hour = eventDate.getHours();
    // Retrieve all geofences from Firestore
    const geofencesSnap = await db.collection('geofences').get();
    for (const doc of geofencesSnap.docs) {
        const gf = doc.data();
        const name = gf.name ?? doc.id;
        // Support two shapes for the geofence center:
        // 1) { center: GeoPoint }
        // 2) { lat: number, lng: number }
        let lat;
        let lng;
        if (gf.center && typeof gf.center.latitude === 'number' && typeof gf.center.longitude === 'number') {
            lat = gf.center.latitude;
            lng = gf.center.longitude;
        }
        else if (typeof gf.lat === 'number' && typeof gf.lng === 'number') {
            lat = gf.lat;
            lng = gf.lng;
        }
        const radius = gf.radiusMeters ?? gf.radius ?? 0;
        if (lat == null || lng == null || radius <= 0) {
            console.warn(`Skipping geofence ${doc.id} due to missing/invalid coordinates or radius.`);
            continue;
        }
        const distance = haversineDistanceMeters(location.latitude, location.longitude, lat, lng);
        if (distance > radius) {
            continue; // User is outside this geofence
        }
        // Time-window evaluation (defaults to 08:00-16:00 on weekdays)
        const allowedStart = gf.allowedStartHour ?? 8;
        const allowedEnd = gf.allowedEndHour ?? 16;
        const isWeekday = day >= 1 && day <= 5;
        const outsideAllowedHours = hour < allowedStart || hour >= allowedEnd;
        if (isWeekday && outsideAllowedHours) {
            await db.collection('alerts').add({
                userId,
                familyId: identity.familyId ?? null,
                triggeredByUid: identity.triggeredByUid,
                triggeredByName: identity.triggeredByName,
                geofenceId: doc.id,
                title: `${identity.triggeredByName} unusual activity at ${name}`,
                message: `Unusual activity detected at ${name}.`,
                timestamp: admin.firestore.FieldValue.serverTimestamp(),
                type: 'geofence',
                seen: false,
            });
        }
    }
    return null;
});
function haversineDistanceMeters(lat1, lon1, lat2, lon2) {
    const R = 6371000; // Radius of Earth in meters
    const toRad = (v) => (v * Math.PI) / 180;
    const dLat = toRad(lat2 - lat1);
    const dLon = toRad(lon2 - lon1);
    const a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
        Math.cos(toRad(lat1)) *
            Math.cos(toRad(lat2)) *
            Math.sin(dLon / 2) *
            Math.sin(dLon / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return R * c;
}
// --- Beta Program Opt-In ---
exports.joinBetaProgram = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }
    const uid = context.auth.uid;
    const fcmToken = data?.fcmToken;
    if (!fcmToken) {
        throw new functions.https.HttpsError('invalid-argument', 'fcmToken required');
    }
    try {
        // Update Firestore flag
        await db.collection('users').doc(uid).set({ isBetaTester: true }, { merge: true });
        // Subscribe token to beta_testers topic
        await admin.messaging().subscribeToTopic([fcmToken], 'beta_testers');
        return { status: 'ok' };
    }
    catch (err) {
        console.error('joinBetaProgram failed', err);
        throw new functions.https.HttpsError('internal', 'joinBetaProgram failed');
    }
});
// --- Feedback to BigQuery ---
exports.onAlertFeedbackCreate = functions.firestore
    .document('alert_feedback/{feedbackId}')
    .onCreate(async (snap) => {
    const data = snap.data();
    if (!data)
        return null;
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
    }
    catch (err) {
        if (err && err.name === 'PartialFailureError') {
            console.error('Partial insert failure', err.errors);
        }
        else {
            console.error('BigQuery insert error', err);
        }
    }
    return null;
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
exports.calculateDriverSafetyScore = functions.pubsub
    .schedule('every monday 01:00')
    .timeZone('Etc/UTC')
    .onRun(async () => {
    const now = new Date();
    const start = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
    const startTs = admin.firestore.Timestamp.fromDate(start);
    const perUser = {};
    // Prefer collection group so apps can store summaries under users/{uid}/driver_safety_summaries
    try {
        const cgSnap = await db
            .collectionGroup('driver_safety_summaries')
            .where('periodStart', '>=', startTs)
            .get();
        for (const doc of cgSnap.docs) {
            const d = doc.data();
            // Derive uid either from field or from path users/{uid}/driver_safety_summaries/{id}
            const pathUid = doc.ref.parent.parent?.id;
            const uid = d.userId || pathUid;
            if (!uid)
                continue;
            const harsh = Number(d.harsh_braking_count || 0);
            const accel = Number(d.rapid_accel_count || 0);
            const agg = perUser[uid] || { harsh: 0, accel: 0 };
            agg.harsh += isFinite(harsh) ? harsh : 0;
            agg.accel += isFinite(accel) ? accel : 0;
            perUser[uid] = agg;
        }
    }
    catch (e) {
        console.warn('collectionGroup(driver_safety_summaries) query failed or unavailable', e);
    }
    // Also support a top-level collection as a fallback: driver_safety_summaries
    try {
        const topSnap = await db
            .collection('driver_safety_summaries')
            .where('periodStart', '>=', startTs)
            .get();
        for (const doc of topSnap.docs) {
            const d = doc.data();
            const uid = d.userId;
            if (!uid)
                continue;
            const harsh = Number(d.harsh_braking_count || 0);
            const accel = Number(d.rapid_accel_count || 0);
            const agg = perUser[uid] || { harsh: 0, accel: 0 };
            agg.harsh += isFinite(harsh) ? harsh : 0;
            agg.accel += isFinite(accel) ? accel : 0;
            perUser[uid] = agg;
        }
    }
    catch (e) {
        console.warn('Top-level driver_safety_summaries query failed', e);
    }
    const updates = [];
    const HARSH_WEIGHT = 20; // points deducted per harsh brake
    const ACCEL_WEIGHT = 15; // points deducted per rapid acceleration
    for (const [uid, agg] of Object.entries(perUser)) {
        const raw = 100 - (agg.harsh * HARSH_WEIGHT + agg.accel * ACCEL_WEIGHT);
        const score = Math.max(0, Math.min(100, Math.round(raw)));
        updates.push(db.collection('users').doc(uid).set({
            driverSafetyScore: score,
            driverSafetyScoreUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true }));
    }
    await Promise.allSettled(updates);
    console.log('calculateDriverSafetyScore updated users:', Object.keys(perUser).length);
    return null;
});
// --- Data Retention Cleanup Function ---
// Scheduled function that runs daily to clean up old documents for privacy and cost management
exports.dataRetentionCleanup = functions.pubsub
    .schedule('every day 02:00')
    .timeZone('Etc/UTC')
    .onRun(async () => {
    console.log('Starting data retention cleanup job');
    const now = admin.firestore.Timestamp.now();
    const thirtyDaysAgo = admin.firestore.Timestamp.fromMillis(now.toMillis() - (30 * 24 * 60 * 60 * 1000));
    const ninetyDaysAgo = admin.firestore.Timestamp.fromMillis(now.toMillis() - (90 * 24 * 60 * 60 * 1000));
    const twelveMonthsAgo = admin.firestore.Timestamp.fromMillis(now.toMillis() - (12 * 30 * 24 * 60 * 60 * 1000));
    const BATCH_SIZE = 500; // Process deletions in batches to avoid memory limits
    let totalDeleted = 0;
    try {
        // 1. Delete location_events older than 30 days
        console.log('Cleaning up location_events older than 30 days...');
        const locationEventsDeleted = await cleanupCollection('location_events', 'timestamp', thirtyDaysAgo, BATCH_SIZE);
        totalDeleted += locationEventsDeleted;
        console.log(`Deleted ${locationEventsDeleted} location_events documents`);
        // 2. Delete alerts older than 90 days
        console.log('Cleaning up alerts older than 90 days...');
        const alertsDeleted = await cleanupCollection('alerts', 'timestamp', ninetyDaysAgo, BATCH_SIZE);
        totalDeleted += alertsDeleted;
        console.log(`Deleted ${alertsDeleted} alerts documents`);
        // 3. Delete support_tickets older than 12 months
        console.log('Cleaning up support_tickets older than 12 months...');
        const supportTicketsDeleted = await cleanupCollection('support_tickets', 'timestamp', twelveMonthsAgo, BATCH_SIZE);
        totalDeleted += supportTicketsDeleted;
        console.log(`Deleted ${supportTicketsDeleted} support_tickets documents`);
        console.log(`Data retention cleanup completed. Total documents deleted: ${totalDeleted}`);
        // Log cleanup summary to a monitoring collection for audit purposes
        await db.collection('cleanup_logs').add({
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
            location_events_deleted: locationEventsDeleted,
            alerts_deleted: alertsDeleted,
            support_tickets_deleted: supportTicketsDeleted,
            total_deleted: totalDeleted,
            status: 'completed'
        });
    }
    catch (error) {
        console.error('Data retention cleanup failed:', error);
        // Log error for monitoring
        await db.collection('cleanup_logs').add({
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
            status: 'failed',
            error: error instanceof Error ? error.message : String(error)
        });
        throw error;
    }
    return null;
});
/**
 * Helper function to clean up documents in a collection older than a specified timestamp
 * Processes deletions in batches to avoid memory limits and timeouts
 */
async function cleanupCollection(collectionName, timestampField, cutoffTimestamp, batchSize) {
    let totalDeleted = 0;
    let hasMore = true;
    while (hasMore) {
        // Query for old documents
        const query = db
            .collection(collectionName)
            .where(timestampField, '<', cutoffTimestamp)
            .limit(batchSize);
        const snapshot = await query.get();
        if (snapshot.empty) {
            hasMore = false;
            break;
        }
        // Create a batch for deletion
        const batch = db.batch();
        snapshot.docs.forEach((doc) => {
            batch.delete(doc.ref);
        });
        // Execute the batch deletion
        await batch.commit();
        totalDeleted += snapshot.docs.length;
        // If we got fewer documents than the batch size, we're done
        if (snapshot.docs.length < batchSize) {
            hasMore = false;
        }
        // Add a small delay between batches to avoid overwhelming Firestore
        if (hasMore) {
            await new Promise(resolve => setTimeout(resolve, 100));
        }
    }
    return totalDeleted;
}
// --- Backfill Family Owner IDs (callable) ---
// Admin-only callable function to backfill ownerId for existing family documents
exports.backfillFamilyOwnerIds = functions.runWith({
    timeoutSeconds: 540, // 9 minutes - max for callable functions
    memory: '1GB'
}).https.onCall(async (data, context) => {
    const adminUids = ['Uv2gOORYXuaTNX7vqldBzyNBlSD3'];
    if (!context.auth || !adminUids.includes(context.auth.uid)) {
        throw new functions.https.HttpsError('permission-denied', 'Admin only');
    }
    console.log('Starting family ownerId backfill process...');
    const batchSize = 200; // Process 200 documents at a time
    let processedCount = 0;
    let updatedCount = 0;
    let batchNumber = 1;
    let hasMore = true;
    let lastDoc = null;
    try {
        while (hasMore) {
            console.log(`Processing batch ${batchNumber}...`);
            // Query for families without ownerId field or with null ownerId
            let query = db.collection('families')
                .where('ownerId', '==', null)
                .limit(batchSize);
            // Handle pagination using the last document from previous batch
            if (lastDoc) {
                query = query.startAfter(lastDoc);
            }
            const snapshot = await query.get();
            if (snapshot.empty) {
                // Also check for documents where ownerId field doesn't exist
                let queryMissing = db.collection('families')
                    .limit(batchSize);
                if (lastDoc) {
                    queryMissing = queryMissing.startAfter(lastDoc);
                }
                const snapshotMissing = await queryMissing.get();
                const docsWithoutOwnerIdField = snapshotMissing.docs.filter((doc) => !doc.data().hasOwnProperty('ownerId'));
                if (docsWithoutOwnerIdField.length === 0) {
                    hasMore = false;
                    break;
                }
                // Process documents without ownerId field
                const batch = db.batch();
                for (const doc of docsWithoutOwnerIdField) {
                    const data = doc.data();
                    const members = data.members;
                    if (Array.isArray(members) && members.length > 0) {
                        const ownerId = members[0];
                        batch.update(doc.ref, { ownerId });
                        updatedCount++;
                        console.log(`Queued update for family ${doc.id}: ownerId = ${ownerId}`);
                    }
                    else {
                        console.warn(`Family ${doc.id} has no members, skipping...`);
                    }
                    processedCount++;
                }
                if (updatedCount > 0) {
                    await batch.commit();
                    console.log(`Batch ${batchNumber} committed: ${docsWithoutOwnerIdField.length} documents processed, ${updatedCount - (updatedCount - docsWithoutOwnerIdField.length)} updated.`);
                }
                lastDoc = docsWithoutOwnerIdField[docsWithoutOwnerIdField.length - 1];
                batchNumber++;
                // Check if we need to continue
                if (docsWithoutOwnerIdField.length < batchSize) {
                    hasMore = false;
                }
                continue;
            }
            // Process the batch of documents with null ownerId
            const batch = db.batch();
            for (const doc of snapshot.docs) {
                const data = doc.data();
                const members = data.members;
                if (Array.isArray(members) && members.length > 0) {
                    const ownerId = members[0];
                    batch.update(doc.ref, { ownerId });
                    updatedCount++;
                    console.log(`Queued update for family ${doc.id}: ownerId = ${ownerId}`);
                }
                else {
                    console.warn(`Family ${doc.id} has no members, skipping...`);
                }
                processedCount++;
            }
            // Commit the batch
            if (snapshot.docs.length > 0) {
                await batch.commit();
                console.log(`Batch ${batchNumber} committed: ${snapshot.docs.length} documents processed.`);
            }
            // Update pagination
            lastDoc = snapshot.docs[snapshot.docs.length - 1];
            batchNumber++;
            // Check if we have more documents to process
            if (snapshot.docs.length < batchSize) {
                hasMore = false;
            }
            // Add a small delay between batches to avoid overwhelming Firestore
            if (hasMore) {
                await new Promise(resolve => setTimeout(resolve, 200));
            }
        }
        const finalMessage = `Backfill complete! Processed ${processedCount} families, updated ${updatedCount} with ownerId.`;
        console.log(finalMessage);
        return {
            success: true,
            message: finalMessage,
            processedCount,
            updatedCount,
            batchesProcessed: batchNumber - 1
        };
    }
    catch (error) {
        console.error('Backfill failed:', error);
        throw new functions.https.HttpsError('internal', `Backfill failed after processing ${processedCount} documents: ${error}`);
    }
});
function dominantEmotionFrom(agg) {
    const entries = Object.entries(agg.emotionCounts);
    if (entries.length === 0)
        return 'unknown';
    entries.sort((a, b) => b[1] - a[1]);
    return entries[0][0];
}
exports.sageWeeklyRecap = (0, scheduler_1.onSchedule)('every monday 08:00', async (_event) => {
    const sevenDaysAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);
    const sevenDaysAgoTs = admin.firestore.Timestamp.fromDate(sevenDaysAgo);
    const weekStart = sevenDaysAgo.toISOString().split('T')[0];
    try {
        const logsSnap = await db
            .collection('wellbeingLogs')
            .where('createdAt', '>=', sevenDaysAgoTs)
            .get();
        const byUser = {};
        for (const doc of logsSnap.docs) {
            const data = doc.data();
            const userId = String(data.userId ?? '').trim();
            if (!userId) {
                continue;
            }
            const agg = byUser[userId] ?? {
                moodSum: 0,
                moodCount: 0,
                totalCheckIns: 0,
                emotionCounts: {},
            };
            const mood = Number(data.mood);
            if (Number.isFinite(mood) && mood >= 1 && mood <= 5) {
                agg.moodSum += mood;
                agg.moodCount += 1;
            }
            const emotion = typeof data.emotion === 'string' ? data.emotion.trim() : '';
            if (emotion) {
                agg.emotionCounts[emotion] = (agg.emotionCounts[emotion] ?? 0) + 1;
            }
            agg.totalCheckIns += 1;
            byUser[userId] = agg;
        }
        for (const [userId, agg] of Object.entries(byUser)) {
            try {
                const avgMood = agg.moodCount > 0 ? agg.moodSum / agg.moodCount : 0;
                const dominantEmotion = dominantEmotionFrom(agg);
                await db
                    .collection('sageSummaries')
                    .doc(userId)
                    .collection('weeks')
                    .doc(weekStart)
                    .set({
                    avgMood,
                    totalCheckIns: agg.totalCheckIns,
                    dominantEmotion,
                    weekStart,
                    generatedAt: admin.firestore.FieldValue.serverTimestamp(),
                }, { merge: true });
                const userDoc = await db.collection('users').doc(userId).get();
                const fcmToken = userDoc.data()?.fcmToken;
                if (typeof fcmToken !== 'string' || fcmToken.trim().length === 0) {
                    continue;
                }
                await admin.messaging().send({
                    token: fcmToken,
                    notification: {
                        title: 'Your weekly Sage recap is ready 🌿',
                        body: `You checked in ${agg.totalCheckIns} times this week.`,
                    },
                });
            }
            catch (error) {
                functions.logger.error('sageWeeklyRecap user processing error', {
                    userId,
                    error: String(error),
                });
            }
        }
    }
    catch (error) {
        functions.logger.error('sageWeeklyRecap failed', { error: String(error) });
    }
    return;
});
//# sourceMappingURL=index.js.map