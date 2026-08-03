#!/usr/bin/env bash
set -euo pipefail
date -u
gcloud auth list 2>&1

PROJECT=msklad-bi-prod
REGION=asia-east1
WORKFLOW=msklad-pipeline-hourly

echo "=== executions list (last 10, hourly) ==="
gcloud workflows executions list "$WORKFLOW" \
  --project="$PROJECT" --location="$REGION" \
  --format="table(name.basename(), state, startTime)" \
  --limit=10

echo "=== executions describe for 17:00Z / 18:00Z / 19:00Z window ==="
for exec_id in $(gcloud workflows executions list "$WORKFLOW" \
  --project="$PROJECT" --location="$REGION" \
  --format="value(name.basename())" --limit=10); do
  gcloud workflows executions describe "$exec_id" \
    --workflow="$WORKFLOW" --project="$PROJECT" --location="$REGION" \
    --format="value(name.basename(), state, startTime)"
done

echo "=== drift_check body via logging, 2026-08-03T16:55Z..2026-08-03T19:30Z ==="
gcloud logging read '
  resource.labels.service_name="cf-dq"
  AND timestamp>="2026-08-03T16:55:00Z"
  AND timestamp<="2026-08-03T19:30:00Z"
' --project="$PROJECT" --format="value(timestamp, textPayload, jsonPayload)" --limit=50 --order=asc

echo "=== workflow CRITICAL body for DQ Gate FAILED, same window ==="
gcloud logging read '
  resource.type="workflows.googleapis.com/Workflow"
  AND severity>=WARNING
  AND timestamp>="2026-08-03T16:55:00Z"
  AND timestamp<="2026-08-03T19:30:00Z"
' --project="$PROJECT" --format="value(timestamp, textPayload, jsonPayload)" --limit=50 --order=asc

date -u
gcloud auth list 2>&1
