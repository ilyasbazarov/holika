#!/usr/bin/env bash
set -euo pipefail

echo "=== date -u (start) ==="
date -u

echo "=== gcloud auth list (start) ==="
gcloud auth list

echo "=== последнее пополнение трёх таблиц (BQ, region asia-east1) ==="
bq --location=asia-east1 query --use_legacy_sql=false --format=prettyjson "
SELECT
  'fact_sales_profit' AS tbl, MAX(_loaded_at) AS last_loaded, COUNT(*) AS row_count
FROM \`msklad-bi-prod.core.fact_sales_profit\`
UNION ALL
SELECT 'fact_purchases', MAX(_loaded_at), COUNT(*)
FROM \`msklad-bi-prod.core.fact_purchases\`
UNION ALL
SELECT 'fact_returns', MAX(_loaded_at), COUNT(*)
FROM \`msklad-bi-prod.core.fact_returns\`
"

echo "=== задания MERGE/LOAD с целью этих трёх таблиц за последние 2 часа (region asia-east1) ==="
bq --location=asia-east1 query --use_legacy_sql=false --format=prettyjson --max_rows=1000 "
SELECT
  job_id, creation_time, end_time, state, error_result.reason AS error_reason,
  error_result.message AS error_message,
  destination_table.table_id AS dest_table
FROM \`msklad-bi-prod\`.\`region-asia-east1\`.INFORMATION_SCHEMA.JOBS_BY_PROJECT
WHERE creation_time >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 2 HOUR)
  AND destination_table.table_id IN ('fact_sales_profit', 'fact_purchases', 'fact_returns', 'fact_sales_staging')
ORDER BY creation_time DESC
"

echo "=== все задания (любая цель) за последний час, для проверки \"жив ли ETL вообще прямо сейчас\" ==="
bq --location=asia-east1 query --use_legacy_sql=false --format=prettyjson --max_rows=1000 "
SELECT job_id, creation_time, state, destination_table.table_id AS dest_table
FROM \`msklad-bi-prod\`.\`region-asia-east1\`.INFORMATION_SCHEMA.JOBS_BY_PROJECT
WHERE creation_time >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 HOUR)
ORDER BY creation_time DESC
"

echo "=== date -u (end) ==="
date -u

echo "=== gcloud auth list (end) ==="
gcloud auth list
