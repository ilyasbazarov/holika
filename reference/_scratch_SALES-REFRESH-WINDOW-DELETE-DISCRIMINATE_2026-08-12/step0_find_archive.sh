#!/usr/bin/env bash
set -euo pipefail

echo "=== date -u (start) ==="
date -u

echo "=== gcloud auth list (start) ==="
gcloud auth list

PROJECT="msklad-bi-prod"
BUCKET="msklad-raw-msklad-bi-prod"
OBJECT="demand/incremental/weekly_run_salesrefreshwindowdeploy106b.ndjson.gz"

echo "=== gcloud storage ls -L (object stat) ==="
gcloud storage ls -L "gs://${BUCKET}/${OBJECT}" --project="${PROJECT}" || echo "STAT_FAILED"

echo "=== gcloud storage ls (prefix listing, sanity) ==="
gcloud storage ls "gs://${BUCKET}/demand/incremental/" --project="${PROJECT}" | grep "salesrefreshwindowdeploy106b" || echo "PREFIX_LISTING_NO_MATCH"

echo "=== date -u (end) ==="
date -u

echo "=== gcloud auth list (end) ==="
gcloud auth list
