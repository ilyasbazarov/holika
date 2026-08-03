#!/usr/bin/env bash
set -euo pipefail
date -u
gcloud auth list 2>&1

PROJECT=msklad-bi-prod
REGION=asia-east1
WORKFLOW=msklad-pipeline-weekly

echo "=== weekly executions list (last 6) ==="
gcloud workflows executions list "$WORKFLOW" \
  --project="$PROJECT" --location="$REGION" \
  --format="table(name.basename(), state, startTime)" \
  --limit=6

echo "=== core.fact_returns: MAX(_loaded_at), MAX(transaction_date), total_rows ==="
bq query --project_id="$PROJECT" --use_legacy_sql=false --format=prettyjson "
SELECT MAX(_loaded_at) AS max_loaded_at, MAX(transaction_date) AS max_d, COUNT(*) AS total_rows
FROM \`$PROJECT.core.fact_returns\`
"

date -u
gcloud auth list 2>&1
