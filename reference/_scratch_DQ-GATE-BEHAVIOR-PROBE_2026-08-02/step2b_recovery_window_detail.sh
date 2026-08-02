#!/usr/bin/env bash
set -euo pipefail

echo "=== date -u (start) ==="
date -u
echo "=== gcloud auth list (start) ==="
gcloud auth list

echo "=== core.fact_sales_profit: MIN(_loaded_at), MAX(_loaded_at), COUNT(*), SUM(revenue_kgs) для transaction_date=2026-07-25 (день, ставший target_date блока отказов) ==="
bq --location=asia-east1 query --use_legacy_sql=false --format=prettyjson --max_rows=10 "
SELECT COUNT(*) AS row_count, MIN(_loaded_at) AS min_loaded_at, MAX(_loaded_at) AS max_loaded_at, SUM(revenue_kgs) AS revenue_kgs_sum
FROM \`msklad-bi-prod\`.\`core\`.\`fact_sales_profit\`
WHERE transaction_date = '2026-07-25'
"

echo "=== core.fact_sales_profit: то же для transaction_date=2026-07-26 (день, целиком блокированный по промоуту) ==="
bq --location=asia-east1 query --use_legacy_sql=false --format=prettyjson --max_rows=10 "
SELECT COUNT(*) AS row_count, MIN(_loaded_at) AS min_loaded_at, MAX(_loaded_at) AS max_loaded_at, SUM(revenue_kgs) AS revenue_kgs_sum
FROM \`msklad-bi-prod\`.\`core\`.\`fact_sales_profit\`
WHERE transaction_date = '2026-07-26'
"

echo "=== BigQuery: полная выгрузка заданий MERGE в core.fact_sales_profit ровно в окне 2026-07-26T17:30:00Z..2026-07-26T19:00:00Z, все поля запроса ==="
bq --location=asia-east1 query --use_legacy_sql=false --format=prettyjson --max_rows=50 "
SELECT job_id, creation_time, end_time, state, statement_type, user_email
FROM \`msklad-bi-prod\`.\`region-asia-east1\`.INFORMATION_SCHEMA.JOBS_BY_PROJECT
WHERE creation_time >= TIMESTAMP('2026-07-26T17:30:00Z')
  AND creation_time <  TIMESTAMP('2026-07-26T19:00:00Z')
  AND destination_table.table_id = 'fact_sales_profit'
ORDER BY creation_time ASC
"

echo "=== Тело провала drift_check В САМОМ ПОСЛЕДНЕМ FAILED прогоне блока (2026-07-26T17:00:02Z) — недельный лог не подходит, ищем execution ID часового workflow ==="
gcloud workflows executions list msklad-pipeline-hourly --location=asia-east1 --limit=500 --format="value(name,state,startTime)" | grep "2026-07-26T17:00" || echo "не найдено по grep"

echo "=== date -u (end) ==="
date -u
echo "=== gcloud auth list (end) ==="
gcloud auth list
