#!/usr/bin/env bash
set -euo pipefail

echo "=== UTC anchor (start) ==="
date -u
echo "=== caller identity (start) ==="
gcloud auth list

echo "=== call cf-facts mode=hourly ==="
gcloud functions call cf-facts \
  --gen2 --region=asia-east1 --project=msklad-bi-prod \
  --data='{"mode":"hourly","run_id":"verify_deploy_2026-08-07_hourly"}'

echo "=== UTC anchor (end) ==="
date -u
echo "=== caller identity (end) ==="
gcloud auth list
