#!/usr/bin/env bash
set -euo pipefail
date -u
gcloud auth list 2>&1

PROJECT=msklad-bi-prod

gcloud logging read '
  resource.labels.service_name="cf-facts"
  AND timestamp>="2026-08-04T18:00:00Z"
  AND timestamp<="2026-08-04T18:06:00Z"
' --project="$PROJECT" --format=json --limit=50 --order=asc

date -u
gcloud auth list 2>&1
