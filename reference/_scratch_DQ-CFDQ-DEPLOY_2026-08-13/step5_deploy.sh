#!/bin/bash
set -euo pipefail
echo "=== date -u (start) ==="
date -u
echo "=== gcloud auth list (start) ==="
gcloud auth list

SOURCE_DIR="$1"

gcloud functions deploy cf-dq \
  --gen2 \
  --runtime=python312 \
  --region=asia-east1 \
  --project=msklad-bi-prod \
  --source="${SOURCE_DIR}" \
  --entry-point=main \
  --trigger-http \
  --service-account=etl-sa@msklad-bi-prod.iam.gserviceaccount.com \
  --memory=512Mi \
  --cpu=0.3333 \
  --timeout=120s \
  --min-instances=1 \
  --max-instances=6 \
  --concurrency=1 \
  --ingress-settings=all \
  --set-env-vars=LOG_EXECUTION_ID=true \
  --set-secrets=MSKLAD_TOKEN=msklad-token:latest

echo "=== gcloud auth list (end) ==="
gcloud auth list
echo "=== date -u (end) ==="
date -u
