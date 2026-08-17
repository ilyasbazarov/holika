#!/usr/bin/env bash
set -euo pipefail

echo "=== UTC anchor (start) ==="
date -u
echo "=== gcloud auth list (start) ==="
gcloud auth list

echo "=== traffic ДО переключения ==="
gcloud run services describe cf-facts --region=asia-east1 --project=msklad-bi-prod --format="value(status.traffic)"

echo "=== переключение трафика на новую ревизию cf-facts-00019-tip ==="
gcloud run services update-traffic cf-facts \
  --region=asia-east1 --project=msklad-bi-prod \
  --to-revisions=cf-facts-00019-tip=100

echo "=== traffic ПОСЛЕ переключения ==="
gcloud run services describe cf-facts --region=asia-east1 --project=msklad-bi-prod --format="value(status.traffic)"

echo "=== UTC anchor (end) ==="
date -u
echo "=== gcloud auth list (end) ==="
gcloud auth list
