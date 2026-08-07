#!/usr/bin/env bash
set -euo pipefail

SCRATCH="reference/_scratch_SALES-PERIMETER-CADENCE-DEPLOY_2026-08-07"
PROJECT="msklad-bi-prod"
LOCATION="asia-east1"
WORKFLOW="msklad-pipeline-weekly"
SOURCE="$SCRATCH/holika-prod/workflows/msklad-pipeline-weekly.yaml"

echo "=== UTC anchor (start) ==="
date -u
echo "=== identity (start) ==="
gcloud auth list

echo "=== deploy ==="
gcloud workflows deploy "$WORKFLOW" \
  --source="$SOURCE" \
  --location="$LOCATION" --project="$PROJECT"

echo "=== identity (end) ==="
gcloud auth list
echo "=== UTC anchor (end) ==="
date -u
