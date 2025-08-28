/*
  Helper script to seed Firestore with initial geofences.
  Usage (inside `functions` directory):
    node dist/src/scripts/setup_geofences.js   // after TypeScript compilation
  or, during local development:
    node src/scripts/setup_geofences.js       // if transpilation not required

  The script creates two sample documents in the top-level `geofences` collection:
    1. "School" – 200 m radius around sample Cairo coordinates.
    2. "Home"   – 150 m radius around different Cairo coordinates.
*/

const admin = require('firebase-admin');

// Initialize the default Firebase app if it hasn't been initialized already.
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

async function main() {
  const geofences = [
    {
      id: 'school',
      data: {
        name: 'School',
        center: new admin.firestore.GeoPoint(30.0444, 31.2357), // Cairo (sample)
        radiusMeters: 200,
        allowedStartHour: 8,
        allowedEndHour: 16,
      },
    },
    {
      id: 'home',
      data: {
        name: 'Home',
        center: new admin.firestore.GeoPoint(30.0500, 31.2330), // Cairo (sample)
        radiusMeters: 150,
        allowedStartHour: 0,
        allowedEndHour: 24,
      },
    },
  ];

  const batch = db.batch();
  geofences.forEach((gf) => {
    const ref = db.collection('geofences').doc(gf.id);
    batch.set(ref, gf.data, { merge: true });
  });

  await batch.commit();
  console.log('✔  Sample geofences have been created/updated successfully.');
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error(err);
    process.exit(1);
  }); 