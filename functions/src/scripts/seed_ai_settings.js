#!/usr/bin/env node
/*
  Seed configuration/ai_settings in Firestore.
  Usage (from functions/):
    node src/scripts/seed_ai_settings.js --project <PROJECT_ID> \
      [--threshold 0.85] [--ml-enabled false]

  Auth:
    - Application Default Credentials (GOOGLE_APPLICATION_CREDENTIALS) or
      `gcloud auth application-default login`
*/

const admin = require('firebase-admin');

function parseArgs() {
  const args = process.argv.slice(2);
  const out = { threshold: 0.85, mlEnabled: false };
  for (let i = 0; i < args.length; i++) {
    const k = args[i];
    const v = args[i + 1];
    if (k === '--project') out.project = v;
    if (k === '--threshold') out.threshold = parseFloat(v);
    if (k === '--ml-enabled') out.mlEnabled = v === 'true';
  }
  if (!out.project) {
    console.error('Missing --project <PROJECT_ID>');
    process.exit(1);
  }
  if (Number.isNaN(out.threshold) || out.threshold <= 0 || out.threshold >= 1) {
    console.error('Invalid --threshold; must be a number between 0 and 1 (e.g., 0.85)');
    process.exit(1);
  }
  return out;
}

async function main() {
  const { project, threshold, mlEnabled } = parseArgs();
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    projectId: project,
  });
  const db = admin.firestore();

  const payload = {
    anomaly_threshold: threshold,
    ml_alerts_enabled: mlEnabled,
    updated_at: admin.firestore.FieldValue.serverTimestamp(),
  };

  await db.collection('configuration').doc('ai_settings').set(payload, { merge: true });
  console.log('Seeded configuration/ai_settings:', payload);
}

main().catch((e) => {
  console.error('Seed failed:', e);
  process.exit(1);
});
