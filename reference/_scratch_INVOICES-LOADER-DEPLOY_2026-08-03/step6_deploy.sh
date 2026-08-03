#!/usr/bin/env bash
set -euo pipefail
date -u
gcloud auth list

SCRATCH_DIR="$(cd "$(dirname "$0")" && pwd)"
SOURCE_DIR="${SCRATCH_DIR}/holika-prod-master/cf-finance"

gcloud functions deploy cf-finance \
  --gen2 \
  --runtime=python312 \
  --region=asia-east1 \
  --project=msklad-bi-prod \
  --source="${SOURCE_DIR}" \
  --entry-point=main \
  --trigger-http \
  --service-account=etl-sa@msklad-bi-prod.iam.gserviceaccount.com \
  --memory=512MB \
  --timeout=1800s \
  --max-instances=16 \
  --set-secrets="MSKLAD_TOKEN=msklad-token:latest"

date -u
gcloud auth list
