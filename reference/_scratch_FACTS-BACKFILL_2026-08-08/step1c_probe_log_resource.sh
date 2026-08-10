#!/usr/bin/env bash
set -euo pipefail
date -u
gcloud auth list 2>&1

PROJECT=msklad-bi-prod

echo "=== any cf-facts logs at all, known-good window 2026-08-04T17:59Z..18:10Z (resume confirm success) ==="
gcloud logging read '
  resource.labels.service_name="cf-facts"
  AND timestamp>="2026-08-04T17:59:00Z"
  AND timestamp<="2026-08-04T18:10:00Z"
' --project="$PROJECT" --format="value(timestamp, resource.type, severity, textPayload, jsonPayload)" --limit=50 --order=asc

date -u
gcloud auth list 2>&1
