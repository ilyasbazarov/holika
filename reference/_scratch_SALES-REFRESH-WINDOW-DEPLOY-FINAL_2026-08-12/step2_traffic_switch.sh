#!/usr/bin/env bash
set -euo pipefail

echo "=== UTC anchor (start) ==="
date -u
echo "=== gcloud auth (start) ==="
gcloud auth list

echo "=== traffic switch: cf-facts -> cf-facts-00017-jon (100%) ==="
gcloud run services update-traffic cf-facts \
  --region=asia-east1 \
  --project=msklad-bi-prod \
  --to-revisions=cf-facts-00017-jon=100

echo "=== read-back: traffic status after switch ==="
gcloud run services describe cf-facts --region=asia-east1 --project=msklad-bi-prod --format="value(status.traffic)"

echo "=== UTC anchor (end) ==="
date -u
echo "=== gcloud auth (end) ==="
gcloud auth list
