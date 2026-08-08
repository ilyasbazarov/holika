#!/usr/bin/env bash
set -euo pipefail
echo "=== date -u (start) ==="
date -u
echo "=== gcloud auth list (start) ==="
gcloud auth list
echo "=== gcloud functions call cf-facts (hourly) ==="
gcloud functions call cf-facts --gen2 --region=asia-east1 --project=msklad-bi-prod \
  --data='{"mode":"hourly","run_id":"verify_deploy_2026-08-08_document_owner_hourly"}'
echo "=== date -u (end) ==="
date -u
echo "=== gcloud auth list (end) ==="
gcloud auth list
