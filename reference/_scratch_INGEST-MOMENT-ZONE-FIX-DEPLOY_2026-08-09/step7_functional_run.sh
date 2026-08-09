#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

echo "=== date -u (start) ==="
date -u
echo "=== gcloud auth list (start) ==="
gcloud auth list

echo "=== вызов cf-facts mode=returns, window_days=100 (покрывает май-2026 — 2026-05-01, зона паритета) ==="
gcloud functions call cf-facts \
  --region=asia-east1 \
  --project=msklad-bi-prod \
  --data='{"mode":"returns","window_days":100,"run_id":"deploy_ingest_moment_zone_fix_returns"}'

echo "=== вызов cf-facts mode=purchases (полный рефреш, без параметров окна) ==="
gcloud functions call cf-facts \
  --region=asia-east1 \
  --project=msklad-bi-prod \
  --data='{"mode":"purchases","run_id":"deploy_ingest_moment_zone_fix_purchases"}'

echo "=== date -u (end) ==="
date -u
echo "=== gcloud auth list (end) ==="
gcloud auth list
