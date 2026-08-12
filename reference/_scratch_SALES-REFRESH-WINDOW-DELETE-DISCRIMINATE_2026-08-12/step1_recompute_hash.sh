#!/usr/bin/env bash
set -euo pipefail

echo "=== date -u (start) ==="
date -u
echo "=== gcloud auth list (start) ==="
gcloud auth list

PROJECT="msklad-bi-prod"
BUCKET="msklad-raw-msklad-bi-prod"
OBJECT="demand/incremental/weekly_run_salesrefreshwindowdeploy106b.ndjson.gz"
LOCAL_GZ="archive_106b.ndjson.gz"
LOCAL_NDJSON="archive_106b.ndjson"

echo "=== downloading archive ==="
gcloud storage cp "gs://${BUCKET}/${OBJECT}" "${LOCAL_GZ}" --project="${PROJECT}"
gunzip -kf "${LOCAL_GZ}"
wc -l "${LOCAL_NDJSON}"

echo "=== running hash recompute + membership check ==="
python3 step1_check.py

echo "=== date -u (end) ==="
date -u
echo "=== gcloud auth list (end) ==="
gcloud auth list
