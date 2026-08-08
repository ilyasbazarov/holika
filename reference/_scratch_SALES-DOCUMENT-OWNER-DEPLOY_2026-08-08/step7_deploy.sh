#!/usr/bin/env bash
set -euo pipefail
echo "=== date -u (start) ==="
date -u
echo "=== gcloud auth list (start) ==="
gcloud auth list
echo "=== gcloud functions deploy cf-facts ==="
gcloud functions deploy cf-facts \
  --gen2 \
  --project=msklad-bi-prod \
  --region=asia-east1 \
  --runtime=python312 \
  --source="/Users/ilyasbazarov/Desktop/msklad_project/holika/worktrees/SALES-DOCUMENT-OWNER-DEPLOY/reference/_scratch_SALES-DOCUMENT-OWNER-DEPLOY_2026-08-08/holika-prod-check/cf-facts" \
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
