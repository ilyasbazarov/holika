#!/usr/bin/env bash
set -euo pipefail
date -u
gcloud auth list 2>&1

PROJECT=msklad-bi-prod

echo "=== stdout log entries for cf-facts, 2026-08-04T18:00Z..18:06Z ==="
gcloud logging read '
  logName="projects/msklad-bi-prod/logs/run.googleapis.com%2Fstdout"
  AND resource.labels.service_name="cf-facts"
  AND timestamp>="2026-08-04T18:00:00Z"
  AND timestamp<="2026-08-04T18:06:00Z"
' --project="$PROJECT" --format="value(timestamp, textPayload)" --limit=50 --order=asc

date -u
gcloud auth list 2>&1
