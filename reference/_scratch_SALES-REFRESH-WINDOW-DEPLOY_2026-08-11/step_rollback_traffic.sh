#!/usr/bin/env bash
set -euo pipefail

PROJECT="msklad-bi-prod"
REGION="asia-east1"
CF="cf-facts"
TARGET_REVISION="cf-facts-00011-mab"

echo "=== UTC anchor (start) ==="
date -u
echo "=== auth identity (start) ==="
gcloud auth list

echo "=== traffic BEFORE ==="
gcloud run services describe "${CF}" --region="${REGION}" --project="${PROJECT}" \
  --format="table(status.traffic[].revisionName,status.traffic[].percent)"

echo "=== update-traffic → ${TARGET_REVISION}=100 ==="
gcloud run services update-traffic "${CF}" \
  --region="${REGION}" --project="${PROJECT}" \
  --to-revisions="${TARGET_REVISION}=100"

echo "=== traffic AFTER ==="
gcloud run services describe "${CF}" --region="${REGION}" --project="${PROJECT}" \
  --format="table(status.traffic[].revisionName,status.traffic[].percent)"

echo "=== auth identity (end) ==="
gcloud auth list
echo "=== UTC anchor (end) ==="
date -u
