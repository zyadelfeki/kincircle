#!/usr/bin/env node
/*
  Upload synthetic location events to Firestore.
  Usage (from functions/):
    node src/scripts/upload_synthetic_data.js --project <PROJECT_ID> [--file src/scripts/test_data.json]

  Authentication:
    - Uses Application Default Credentials (GOOGLE_APPLICATION_CREDENTIALS)
      or gcloud auth application-default login.
*/

const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');

function parseArgs() {
  const out = { file: 'src/scripts/test_data.json' };
  const args = process.argv.slice(2);
  for (let i = 0; i < args.length; i++) {
    const key = args[i];
    const val = args[i + 1];
    if (key === '--project') out.project = val;
    if (key === '--file') out.file = val;
  }
  if (!out.project) {
    console.error('Missing --project <PROJECT_ID>');
    process.exit(1);
  }
  return out;
}

async function main() {
  const { project, file } = parseArgs();
  const filePath = path.resolve(process.cwd(), file);
  if (!fs.existsSync(filePath)) {
    console.error(`File not found: ${filePath}`);
    process.exit(1);
  }
  const raw = fs.readFileSync(filePath, 'utf8');
  const events = JSON.parse(raw);

  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    projectId: project,
  });
  const db = admin.firestore();

  console.log(`Uploading ${events.length} events to project ${project} ...`);
  let success = 0;
  for (const ev of events) {
    try {
      const doc = {
        userId: ev.userId,
        location: new admin.firestore.GeoPoint(ev.location.latitude, ev.location.longitude),
        timestamp: admin.firestore.Timestamp.fromDate(new Date(ev.timestamp)),
      };
      await db.collection('location_events').add(doc);
      success++;
    } catch (e) {
      console.error('Failed to insert event:', e);
    }
  }
  console.log(`Done. Inserted ${success}/${events.length} events.`);
}

main().catch((e) => {
  console.error('Upload failed:', e);
  process.exit(1);
});
