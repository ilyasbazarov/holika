#!/usr/bin/env bash
set -euo pipefail

date -u
gcloud auth list

echo "=== traffic switch: cf-facts -> cf-facts-00011-mab (100%) ==="
gcloud run services update-traffic cf-facts --to-revisions=cf-facts-00011-mab=100 \
  --region=asia-east1 --project=msklad-bi-prod

echo "=== read-back 1: traffic status after switch ==="
gcloud run services describe cf-facts \
  --region=asia-east1 --project=msklad-bi-prod \
  --format="table(status.traffic.revisionName, status.traffic.percent)"

date -u
gcloud auth list
