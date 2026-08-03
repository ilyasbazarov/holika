#!/usr/bin/env bash
set -euo pipefail
date -u
gcloud auth list 2>&1

PROJECT=msklad-bi-prod
REGION=asia-east1
WORKFLOW=msklad-pipeline-hourly

# Ждём до 2026-08-03T19:05:00Z, чтобы прогон 19:00:02Z успел завершиться и залогироваться.
until [ "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '>' "2026-08-03T19:05:00Z" ]; do
  sleep 30
done

echo "=== executions list (last 5, hourly) ==="
gcloud workflows executions list "$WORKFLOW" \
  --project="$PROJECT" --location="$REGION" \
  --format="table(name.basename(), state, startTime)" \
  --limit=5

echo "=== drift_check / DQ Gate FAILED body, 2026-08-03T18:55Z..19:30Z ==="
gcloud logging read '
  resource.type="workflows.googleapis.com/Workflow"
  AND severity>=WARNING
  AND timestamp>="2026-08-03T18:55:00Z"
  AND timestamp<="2026-08-03T19:30:00Z"
' --project="$PROJECT" --format="value(timestamp, textPayload, jsonPayload)" --limit=50 --order=asc

date -u
gcloud auth list 2>&1
