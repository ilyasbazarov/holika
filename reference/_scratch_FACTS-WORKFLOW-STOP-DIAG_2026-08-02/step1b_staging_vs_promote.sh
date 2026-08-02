#!/usr/bin/env bash
set -euo pipefail

echo "=== date -u (start) ==="
date -u
echo "=== gcloud auth list (start) ==="
gcloud auth list

echo "=== ВСЕ задания за 24 часа с целью fact_sales_staging (hourly step_facts) ==="
bq --location=asia-east1 query --use_legacy_sql=false --format=prettyjson --max_rows=1000 "
SELECT job_id, creation_time, end_time, state, error_result.reason AS error_reason, error_result.message AS error_message
FROM \`msklad-bi-prod\`.\`region-asia-east1\`.INFORMATION_SCHEMA.JOBS_BY_PROJECT
WHERE creation_time >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 24 HOUR)
  AND destination_table.table_id = 'fact_sales_staging'
ORDER BY creation_time ASC
"

echo "=== ВСЕ задания за 24 часа с целью fact_sales_profit (promote) — успешные и ошибочные ==="
bq --location=asia-east1 query --use_legacy_sql=false --format=prettyjson --max_rows=1000 "
SELECT job_id, creation_time, end_time, state, error_result.reason AS error_reason, error_result.message AS error_message, statement_type
FROM \`msklad-bi-prod\`.\`region-asia-east1\`.INFORMATION_SCHEMA.JOBS_BY_PROJECT
WHERE creation_time >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 24 HOUR)
  AND destination_table.table_id = 'fact_sales_profit'
ORDER BY creation_time ASC
"

echo "=== ВСЕ задания за 24 часа с целью fact_purchases — успешные и ошибочные ==="
bq --location=asia-east1 query --use_legacy_sql=false --format=prettyjson --max_rows=1000 "
SELECT job_id, creation_time, end_time, state, error_result.reason AS error_reason, error_result.message AS error_message, statement_type
FROM \`msklad-bi-prod\`.\`region-asia-east1\`.INFORMATION_SCHEMA.JOBS_BY_PROJECT
WHERE creation_time >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 24 HOUR)
  AND destination_table.table_id = 'fact_purchases'
ORDER BY creation_time ASC
"

echo "=== Любые задания за 24ч с ЛЮБОЙ ошибкой (error_result непусто), region asia-east1 ==="
bq --location=asia-east1 query --use_legacy_sql=false --format=prettyjson --max_rows=1000 "
SELECT job_id, creation_time, destination_table.table_id AS dest_table, error_result.reason AS error_reason, error_result.message AS error_message
FROM \`msklad-bi-prod\`.\`region-asia-east1\`.INFORMATION_SCHEMA.JOBS_BY_PROJECT
WHERE creation_time >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 24 HOUR)
  AND error_result IS NOT NULL
ORDER BY creation_time ASC
"

echo "=== date -u (end) ==="
date -u
echo "=== gcloud auth list (end) ==="
gcloud auth list
