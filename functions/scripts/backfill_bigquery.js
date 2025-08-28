#!/usr/bin/env node
/*
  Backfill JSONL rows into a BigQuery table.
  Usage (from functions/):
    node scripts/backfill_bigquery.js --dataset <DATASET> --table <TABLE> --file <PATH_TO_JSONL>

  Each line in the input file must be a valid JSON object whose keys match the table schema.
*/

const fs = require('fs');
const path = require('path');
const { BigQuery } = require('@google-cloud/bigquery');

function parseArgs() {
  const args = process.argv.slice(2);
  const out = {};
  for (let i = 0; i < args.length; i += 2) {
    const key = args[i];
    const val = args[i + 1];
    if (!val || !key.startsWith('--')) continue;
    out[key.substring(2)] = val;
  }
  return out;
}

async function main() {
  const { dataset, table, file } = parseArgs();
  if (!dataset || !table || !file) {
    console.error('Missing args. Usage: --dataset <DATASET> --table <TABLE> --file <PATH_TO_JSONL>');
    process.exit(1);
  }

  const bq = new BigQuery();
  const filePath = path.resolve(process.cwd(), file);
  if (!fs.existsSync(filePath)) {
    console.error(`File not found: ${filePath}`);
    process.exit(1);
  }

  const lines = fs
    .readFileSync(filePath, 'utf8')
    .split(/\r?\n/)
    .filter((l) => l.trim().length > 0);

  const rows = [];
  for (const line of lines) {
    try {
      const obj = JSON.parse(line);
      rows.push(obj);
    } catch (e) {
      console.error('Invalid JSON line:', line);
      process.exit(1);
    }
  }

  if (rows.length === 0) {
    console.log('No rows to insert.');
    return;
  }

  try {
    await bq.dataset(dataset).table(table).insert(rows);
    console.log(`Inserted ${rows.length} row(s) into ${dataset}.${table}`);
  } catch (err) {
    if (err && err.name === 'PartialFailureError') {
      console.error('Partial insert failure:', JSON.stringify(err.errors, null, 2));
    } else {
      console.error('BigQuery insert error:', err);
    }
    process.exit(1);
  }
}

main().catch((e) => {
  console.error('Backfill failed:', e);
  process.exit(1);
});
