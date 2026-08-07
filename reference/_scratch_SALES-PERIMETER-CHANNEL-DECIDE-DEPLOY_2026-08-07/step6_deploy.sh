#!/usr/bin/env bash
set -euo pipefail

SOURCE_DIR="/Users/ilyasbazarov/Desktop/msklad_project/holika/worktrees/SALES-PERIMETER-CHANNEL-DECIDE-DEPLOY/reference/_scratch_SALES-PERIMETER-CHANNEL-DECIDE-DEPLOY_2026-08-07/branch_check/repo/cf-facts"

echo "=== UTC anchor (start) ==="
date -u
echo "=== caller identity (start) ==="
gcloud auth list

echo "=== deploy cf-facts from branch checkout (${SOURCE_DIR}) ==="
gcloud functions deploy cf-facts \
  --gen2 \
  --project=msklad-bi-prod \
  --runtime=python312 \
  --region=asia-east1 \
  --source="${SOURCE_DIR}" \
  --entry-point=main \
  --service-account=etl-sa@msklad-bi-prod.iam.gserviceaccount.com \
  --memory=2048MB \
  --timeout=540s \
  --min-instances=1 \
  --max-instances=5 \
  --ingress-settings=all \
  --set-secrets="MSKLAD_TOKEN=msklad-token:latest"

echo "=== UTC anchor (end) ==="
date -u
echo "=== caller identity (end) ==="
gcloud auth list
