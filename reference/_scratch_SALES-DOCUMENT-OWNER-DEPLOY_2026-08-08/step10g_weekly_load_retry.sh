#!/usr/bin/env bash
set -euo pipefail
echo "=== date -u (start) ==="
date -u
echo "=== gcloud auth list (start) ==="
gcloud auth list
echo "=== gcloud functions call cf-facts (weekly load, retry) ==="
gcloud functions call cf-facts --gen2 --region=asia-east1 --project=msklad-bi-prod \
  --data='{"mode":"weekly","run_id":"verify_deploy_2026-08-08_document_owner_weekly_retry2"}'
echo "=== date -u (end) ==="
date -u
echo "=== gcloud auth list (end) ==="
gcloud auth list
