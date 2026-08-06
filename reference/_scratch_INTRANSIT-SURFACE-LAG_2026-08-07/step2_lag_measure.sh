#!/bin/bash
set -euo pipefail

echo "=== date -u (start) ==="
date -u

echo "=== gcloud auth list (start) ==="
gcloud auth list

echo "=== marts.in_transit MAX(_mart_refreshed_at) ==="
bq query --use_legacy_sql=false --format=json \
  'SELECT MAX(_mart_refreshed_at) AS max_mart_refreshed_at FROM `msklad-bi-prod.marts.in_transit`'

echo "=== core.fact_purchases MAX(_loaded_at) ==="
bq query --use_legacy_sql=false --format=json \
  'SELECT MAX(_loaded_at) AS max_loaded_at FROM `msklad-bi-prod.core.fact_purchases`'

echo "=== gcloud auth list (end) ==="
gcloud auth list

echo "=== date -u (end) ==="
date -u
