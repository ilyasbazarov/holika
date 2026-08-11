#!/usr/bin/env bash
set -euo pipefail

SCRATCH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT="msklad-bi-prod"
REGION="asia-east1"
SOURCE="${SCRATCH}/holika-prod/cf-facts"

echo "=== UTC anchor (start) ==="
date -u
echo "=== auth identity (start) ==="
gcloud auth list

echo "=== deploy cf-facts from ${SOURCE} ==="
gcloud functions deploy cf-facts \
  --gen2 \
  --runtime=python312 \
  --region="${REGION}" \
  --project="${PROJECT}" \
  --source="${SOURCE}" \
  --entry-point=main \
  --service-account=etl-sa@msklad-bi-prod.iam.gserviceaccount.com \
  --memory=2048MB \
  --timeout=540s \
  --min-instances=1 \
  --set-secrets="MSKLAD_TOKEN=msklad-token:latest"

echo "=== auth identity (end) ==="
gcloud auth list
echo "=== UTC anchor (end) ==="
date -u
