#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

echo "=== date -u (start) ==="
date -u
echo "=== gcloud auth list (start) ==="
gcloud auth list

echo "=== gcloud functions deploy cf-facts ==="
gcloud functions deploy cf-facts \
  --gen2 \
  --runtime=python312 \
  --region=asia-east1 \
  --project=msklad-bi-prod \
  --source=code_repo/cf-facts \
  --entry-point=main \
  --service-account=etl-sa@msklad-bi-prod.iam.gserviceaccount.com \
  --memory=2048MB \
  --timeout=540s \
  --min-instances=1 \
  --set-secrets="MSKLAD_TOKEN=msklad-token:latest"

echo "=== date -u (end) ==="
date -u
echo "=== gcloud auth list (end) ==="
gcloud auth list
