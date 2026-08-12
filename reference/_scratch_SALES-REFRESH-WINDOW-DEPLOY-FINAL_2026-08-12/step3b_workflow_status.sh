#!/usr/bin/env bash
set -euo pipefail

echo "=== UTC anchor (start) ==="
date -u
echo "=== gcloud auth (start) ==="
gcloud auth list

LOC=asia-east1
echo "=== list workflows in project (identify hourly workflow name) ==="
gcloud workflows list --project=msklad-bi-prod --location=$LOC --format="value(name.scope(workflows))"

echo "=== recent executions of hourly workflow (last 5) ==="
WF=msklad-pipeline-hourly
gcloud workflows executions list "$WF" --project=msklad-bi-prod --location=$LOC --limit=5 \
  --format="table(name.scope(executions),state,startTime,endTime)"

echo "=== full detail of most recent execution ==="
LATEST=$(gcloud workflows executions list "$WF" --project=msklad-bi-prod --location=$LOC --limit=1 --format="value(name.scope(executions))")
gcloud workflows executions describe "$LATEST" --workflow="$WF" --project=msklad-bi-prod --location=$LOC --format=json > latest_execution.json
cat latest_execution.json

echo "=== UTC anchor (end) ==="
date -u
echo "=== gcloud auth (end) ==="
gcloud auth list
