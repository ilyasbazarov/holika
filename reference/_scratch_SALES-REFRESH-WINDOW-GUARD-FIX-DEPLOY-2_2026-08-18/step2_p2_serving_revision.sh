#!/usr/bin/env bash
set -euo pipefail

echo "=== UTC anchor (start) ==="
date -u
echo "=== gcloud auth list (start) ==="
gcloud auth list

echo "=== П2: обслуживающая ревизия cf-facts (read-only) ==="
gcloud run services describe cf-facts \
  --project=msklad-bi-prod --region=asia-east1 \
  --format="value(status.traffic)"

echo "=== П2: то же в yaml для читаемости ==="
gcloud run services describe cf-facts \
  --project=msklad-bi-prod --region=asia-east1 \
  --format="yaml(status.traffic)"

echo "=== UTC anchor (end) ==="
date -u
echo "=== gcloud auth list (end) ==="
gcloud auth list
