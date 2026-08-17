#!/usr/bin/env bash
set -euo pipefail

echo "=== UTC anchor (start) ==="
date -u
echo "=== gcloud auth (start) ==="
gcloud auth list

PROJECT=msklad-bi-prod
LOC=asia-east1
WF=msklad-pipeline-weekly

echo "=== executions of $WF since 2026-08-15 ==="
gcloud workflows executions list "$WF" --project="$PROJECT" --location="$LOC" --limit=10 \
  --format="table(name.scope(executions),state,startTime,endTime)"

echo "=== full detail of execution closest to 2026-08-16T01:00Z (most recent within window) ==="
LATEST=$(gcloud workflows executions list "$WF" --project="$PROJECT" --location="$LOC" --limit=1 \
  --format="value(name.scope(executions))")
gcloud workflows executions describe "$LATEST" --workflow="$WF" --project="$PROJECT" --location="$LOC" \
  --format=json > latest_weekly_execution.json
cat latest_weekly_execution.json

echo "=== UTC anchor (end) ==="
date -u
echo "=== gcloud auth (end) ==="
gcloud auth list
