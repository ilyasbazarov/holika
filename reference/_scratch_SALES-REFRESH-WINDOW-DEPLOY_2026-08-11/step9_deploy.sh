#!/usr/bin/env bash
set -euo pipefail
echo "=== date -u (start) ==="
date -u
echo "=== gcloud auth list (start) ==="
gcloud auth list
echo "=== deploy cf-facts from branch source ==="
gcloud functions deploy cf-facts \
  --gen2 --runtime=python312 --region=asia-east1 \
  --source="/Users/ilyasbazarov/Desktop/msklad_project/holika_provenance_archive/SALES-REFRESH-WINDOW-DEPLOY_2026-08-11_holika-prod/cf-facts" --entry-point=main \
  --service-account=etl-sa@msklad-bi-prod.iam.gserviceaccount.com \
  --memory=2048MB --timeout=540s \
  --project=msklad-bi-prod
echo "=== describe после деплоя ==="
gcloud functions describe cf-facts --gen2 --region=asia-east1 --project=msklad-bi-prod --format=json
echo "=== traffic ==="
gcloud run services describe cf-facts --region=asia-east1 --project=msklad-bi-prod --format=json
echo "=== gcloud auth list (end) ==="
gcloud auth list
echo "=== date -u (end) ==="
date -u
