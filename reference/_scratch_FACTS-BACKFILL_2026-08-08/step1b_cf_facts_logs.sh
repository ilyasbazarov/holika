#!/usr/bin/env bash
set -euo pipefail
date -u
gcloud auth list 2>&1

PROJECT=msklad-bi-prod

echo "=== cf-facts logs mentioning mode=purchases / mode=returns / CF-Facts complete|start, 2026-07-27T00:00Z..now ==="
gcloud logging read '
  resource.type="cloud_run_revision"
  AND resource.labels.service_name="cf-facts"
  AND (textPayload:"mode=purchases" OR textPayload:"mode=returns" OR textPayload:"purchase_positions" OR textPayload:"return_positions")
  AND timestamp>="2026-07-27T00:00:00Z"
' --project="$PROJECT" --format="value(timestamp, severity, textPayload)" --limit=500 --order=asc

echo "=== ERROR-severity workflow logs naming step_purchases/step_returns FAILED, 2026-07-27T00:00Z..now ==="
gcloud logging read '
  resource.type="workflows.googleapis.com/Workflow"
  AND resource.labels.workflow_id="msklad-pipeline-weekly"
  AND severity>=ERROR
  AND (textPayload:"step_purchases" OR textPayload:"step_returns")
  AND timestamp>="2026-07-27T00:00:00Z"
' --project="$PROJECT" --format="value(timestamp, severity, textPayload)" --limit=200 --order=asc

date -u
gcloud auth list 2>&1
