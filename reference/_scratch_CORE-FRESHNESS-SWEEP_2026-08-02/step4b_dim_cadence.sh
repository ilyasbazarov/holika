#!/bin/bash
set -euo pipefail
echo "=== date -u (start) ==="
date -u
echo "=== gcloud auth list (start) ==="
gcloud auth list

PROJECT="msklad-bi-prod"
LOCATION="asia-east1"

echo ""
echo "=== distinct _loaded_at за 24ч по core.dim_products (проверка фактической каденции cf-dim) ==="
bq query --project_id="${PROJECT}" --location="${LOCATION}" --use_legacy_sql=false --max_rows=100 --format=prettyjson "
SELECT _loaded_at, COUNT(*) AS n
FROM \`${PROJECT}.core.dim_products\`
WHERE _loaded_at >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 24 HOUR)
GROUP BY _loaded_at
ORDER BY _loaded_at DESC
"

echo ""
echo "=== JOBS_BY_PROJECT (24ч) — задания с целью core.dim_products ==="
bq query --project_id="${PROJECT}" --location="${LOCATION}" --use_legacy_sql=false --max_rows=100 --format=prettyjson "
SELECT creation_time, job_id, state, statement_type
FROM \`${PROJECT}\`.\`region-${LOCATION}\`.INFORMATION_SCHEMA.JOBS_BY_PROJECT
WHERE creation_time >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 24 HOUR)
  AND destination_table.dataset_id = 'core'
  AND destination_table.table_id = 'dim_products'
ORDER BY creation_time DESC
"

echo "=== gcloud auth list (end) ==="
gcloud auth list
echo "=== date -u (end) ==="
date -u
