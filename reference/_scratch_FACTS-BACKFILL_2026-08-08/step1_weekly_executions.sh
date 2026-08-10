#!/usr/bin/env bash
set -euo pipefail
date -u
gcloud auth list 2>&1

PROJECT=msklad-bi-prod
REGION=asia-east1
WORKFLOW=msklad-pipeline-weekly

echo "=== weekly executions list, 2026-07-27T00:00Z..now ==="
gcloud workflows executions list "$WORKFLOW" \
  --project="$PROJECT" --location="$REGION" \
  --format="table(name.basename(), state, startTime, endTime)" \
  --limit=20

echo "=== per-execution describe (name, state, start, end) ==="
for exec_id in $(gcloud workflows executions list "$WORKFLOW" \
  --project="$PROJECT" --location="$REGION" \
  --format="value(name.basename())" --limit=20); do
  gcloud workflows executions describe "$exec_id" \
    --workflow="$WORKFLOW" --project="$PROJECT" --location="$REGION" \
    --format="value(name.basename(), state, startTime, endTime)"
done

echo "=== step_purchases / step_returns markers in workflow logs, 2026-07-27T00:00Z..now ==="
gcloud logging read '
  resource.type="workflows.googleapis.com/Workflow"
  AND resource.labels.workflow_id="msklad-pipeline-weekly"
  AND (textPayload:"step_purchases" OR textPayload:"step_returns" OR textPayload:"WEEKLY")
  AND timestamp>="2026-07-27T00:00:00Z"
' --project="$PROJECT" --format="value(timestamp, severity, textPayload)" --limit=300 --order=asc

date -u
gcloud auth list 2>&1
