#!/usr/bin/env bash
set -euo pipefail
echo "=== date -u (start) ==="; date -u
echo "=== gcloud auth list (start) ==="; gcloud auth list
echo "=== post-run freshness core.fact_inventory ==="
bq query --use_legacy_sql=false --max_rows=50 '
SELECT date_snapshot, MAX(_loaded_at) AS max_loaded_at, COUNT(*) AS row_count
FROM `msklad-bi-prod.core.fact_inventory`
GROUP BY date_snapshot
ORDER BY date_snapshot DESC
LIMIT 5
'
echo "=== date -u (end) ==="; date -u
echo "=== gcloud auth list (end) ==="; gcloud auth list
