#!/usr/bin/env node
/*
  Generate a realistic 30-day location history for a test user.
  Output: test_data.json (array of events) alongside this script.
*/

const fs = require('fs');
const path = require('path');

// Hard-coded school coordinate (SF) and 200m radius
const SCHOOL = { lat: 37.7596, lng: -122.4269 };
const RADIUS_M = 200;
const TEST_USER_ID = 'test_user';

function metersToDegreesLat(meters) {
  return meters / 111320; // approx meters to degrees latitude
}

function metersToDegreesLng(meters, atLat) {
  return meters / (111320 * Math.cos((atLat * Math.PI) / 180));
}

// Jitter around a base lat/lng within maxMeters
function jitterMeters(lat, lng, maxMeters) {
  const dx = (Math.random() * 2 - 1) * maxMeters;
  const dy = (Math.random() * 2 - 1) * maxMeters;
  return {
    lat: lat + metersToDegreesLat(dy),
    lng: lng + metersToDegreesLng(dx, lat),
  };
}

function isoAt(date, hour, minute = 0) {
  const d = new Date(date);
  d.setHours(hour, minute, 0, 0);
  return d.toISOString();
}

function isWeekday(date) {
  const day = date.getDay();
  return day >= 1 && day <= 5;
}

function generate30Days() {
  const events = [];
  const now = new Date();
  for (let i = 29; i >= 0; i--) {
    const day = new Date(now);
    day.setDate(now.getDate() - i);

    // Inside school hours (10:00) near school
    const inHours = jitterMeters(SCHOOL.lat, SCHOOL.lng, RADIUS_M - 30);
    events.push({
      userId: TEST_USER_ID,
      location: { latitude: inHours.lat, longitude: inHours.lng },
      timestamp: isoAt(day, 10),
    });

    // Outside school hours near school on weekdays (06:30 and 20:00)
    if (isWeekday(day)) {
      const morning = jitterMeters(SCHOOL.lat, SCHOOL.lng, RADIUS_M - 30);
      events.push({
        userId: TEST_USER_ID,
        location: { latitude: morning.lat, longitude: morning.lng },
        timestamp: isoAt(day, 6, 30),
      });

      const evening = jitterMeters(SCHOOL.lat, SCHOOL.lng, RADIUS_M - 30);
      events.push({
        userId: TEST_USER_ID,
        location: { latitude: evening.lat, longitude: evening.lng },
        timestamp: isoAt(day, 20, 0),
      });
    }

    // Elsewhere random point during the day (non-school)
    const elsewhereBase = { lat: 37.7749, lng: -122.4194 }; // SF center-ish
    const elsewhere = jitterMeters(elsewhereBase.lat, elsewhereBase.lng, 2000);
    events.push({
      userId: TEST_USER_ID,
      location: { latitude: elsewhere.lat, longitude: elsewhere.lng },
      timestamp: isoAt(day, 14, 15),
    });
  }
  return events;
}

function main() {
  const events = generate30Days();
  const outPath = path.resolve(__dirname, 'test_data.json');
  fs.writeFileSync(outPath, JSON.stringify(events, null, 2));
  console.log(`Wrote ${events.length} events to ${outPath}`);
}

main();