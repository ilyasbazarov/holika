#!/usr/bin/env bash
set -euo pipefail
echo "=== date -u (start) ==="
date -u
echo "=== gcloud auth list (start) ==="
gcloud auth list
echo "=== П2: COUNT(*) core.fact_sales_profit ==="
bq query --use_legacy_sql=false --project_id=msklad-bi-prod --format=prettyjson \
  'SELECT COUNT(*) AS cnt, CURRENT_TIMESTAMP() AS measured_at_utc FROM `msklad-bi-prod.core.fact_sales_profit`'
echo "=== gcloud auth list (end) ==="
gcloud auth list
echo "=== date -u (end) ==="
date -u
