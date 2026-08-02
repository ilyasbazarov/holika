#!/bin/bash
set -euo pipefail
echo "=== date -u (start) ==="
date -u
echo "=== gcloud auth list (start) ==="
gcloud auth list

PROJECT="msklad-bi-prod"
LOCATION="asia-east1"

echo ""
echo "=== JOBS_BY_PROJECT (24ч) — задания с целью core.fact_sales_profit (проверка почасовой промоции) ==="
bq query --project_id="${PROJECT}" --location="${LOCATION}" --use_legacy_sql=false --max_rows=200 --format=prettyjson "
SELECT creation_time, job_id, state, statement_type, error_result.reason AS error_reason
FROM \`${PROJECT}\`.\`region-${LOCATION}\`.INFORMATION_SCHEMA.JOBS_BY_PROJECT
WHERE creation_time >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 24 HOUR)
  AND destination_table.dataset_id = 'core'
  AND destination_table.table_id = 'fact_sales_profit'
ORDER BY creation_time DESC
"

echo ""
echo "=== JOBS_BY_PROJECT (24ч) — задания с целью core.fact_purchases ==="
bq query --project_id="${PROJECT}" --location="${LOCATION}" --use_legacy_sql=false --max_rows=200 --format=prettyjson "
SELECT creation_time, job_id, state, statement_type, error_result.reason AS error_reason
FROM \`${PROJECT}\`.\`region-${LOCATION}\`.INFORMATION_SCHEMA.JOBS_BY_PROJECT
WHERE creation_time >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 24 HOUR)
  AND destination_table.dataset_id = 'core'
  AND destination_table.table_id = 'fact_purchases'
ORDER BY creation_time DESC
"

echo ""
echo "=== JOBS_BY_PROJECT (90 суток) — задания с целью core.dim_metadata_mappings ==="
bq query --project_id="${PROJECT}" --location="${LOCATION}" --use_legacy_sql=false --max_rows=200 --format=prettyjson "
SELECT creation_time, job_id, state, statement_type
FROM \`${PROJECT}\`.\`region-${LOCATION}\`.INFORMATION_SCHEMA.JOBS_BY_PROJECT
WHERE creation_time >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 90 DAY)
  AND destination_table.dataset_id = 'core'
  AND destination_table.table_id = 'dim_metadata_mappings'
ORDER BY creation_time DESC
"

echo ""
echo "=== JOBS_BY_PROJECT (90 суток) — задания с целью core.fact_sales_profit_byvariant_backup ==="
bq query --project_id="${PROJECT}" --location="${LOCATION}" --use_legacy_sql=false --max_rows=200 --format=prettyjson "
SELECT creation_time, job_id, state, statement_type
FROM \`${PROJECT}\`.\`region-${LOCATION}\`.INFORMATION_SCHEMA.JOBS_BY_PROJECT
WHERE creation_time >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 90 DAY)
  AND destination_table.dataset_id = 'core'
  AND destination_table.table_id = 'fact_sales_profit_byvariant_backup'
ORDER BY creation_time DESC
"

echo ""
echo "=== JOBS_BY_PROJECT (90 суток) — задания с целью core.fact_returns ==="
bq query --project_id="${PROJECT}" --location="${LOCATION}" --use_legacy_sql=false --max_rows=200 --format=prettyjson "
SELECT creation_time, job_id, state, statement_type
FROM \`${PROJECT}\`.\`region-${LOCATION}\`.INFORMATION_SCHEMA.JOBS_BY_PROJECT
WHERE creation_time >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 90 DAY)
  AND destination_table.dataset_id = 'core'
  AND destination_table.table_id = 'fact_returns'
ORDER BY creation_time DESC
"

echo "=== gcloud auth list (end) ==="
gcloud auth list
echo "=== date -u (end) ==="
date -u
