#!/usr/bin/env bash
set -euo pipefail

echo "=== date -u (start) ==="
date -u
echo "=== gcloud auth list (start) ==="
gcloud auth list

echo "=== Executions: msklad-pipeline-hourly, limit=500 (покрыть 2026-07-15..2026-08-02) ==="
gcloud workflows executions list msklad-pipeline-hourly --location=asia-east1 --limit=500 --format=json

echo "=== Executions: msklad-pipeline-weekly, limit=50 (покрыть 2026-07-15..2026-08-02) ==="
gcloud workflows executions list msklad-pipeline-weekly --location=asia-east1 --limit=50 --format=json

echo "=== BigQuery jobs с целью core.fact_sales_profit за 2026-07-15..2026-08-02 (region asia-east1), с user_email и statement_type ==="
bq --location=asia-east1 query --use_legacy_sql=false --format=prettyjson --max_rows=1000 "
SELECT job_id, creation_time, end_time, state, statement_type, user_email,
       error_result.reason AS error_reason, error_result.message AS error_message
FROM \`msklad-bi-prod\`.\`region-asia-east1\`.INFORMATION_SCHEMA.JOBS_BY_PROJECT
WHERE creation_time >= TIMESTAMP('2026-07-15T00:00:00Z')
  AND creation_time <  TIMESTAMP('2026-08-02T23:59:59Z')
  AND destination_table.table_id = 'fact_sales_profit'
ORDER BY creation_time ASC
"

echo "=== Независимый COUNT(*) заданий с целью core.fact_sales_profit за тот же период (region asia-east1) ==="
bq --location=asia-east1 query --use_legacy_sql=false --format=prettyjson --max_rows=10 "
SELECT COUNT(*) AS job_count
FROM \`msklad-bi-prod\`.\`region-asia-east1\`.INFORMATION_SCHEMA.JOBS_BY_PROJECT
WHERE creation_time >= TIMESTAMP('2026-07-15T00:00:00Z')
  AND creation_time <  TIMESTAMP('2026-08-02T23:59:59Z')
  AND destination_table.table_id = 'fact_sales_profit'
"

echo "=== То же самое в region US (на случай, если часть заданий не в asia-east1) ==="
bq --location=US query --use_legacy_sql=false --format=prettyjson --max_rows=1000 "
SELECT job_id, creation_time, end_time, state, statement_type, user_email,
       error_result.reason AS error_reason, error_result.message AS error_message
FROM \`msklad-bi-prod\`.\`region-us\`.INFORMATION_SCHEMA.JOBS_BY_PROJECT
WHERE creation_time >= TIMESTAMP('2026-07-15T00:00:00Z')
  AND creation_time <  TIMESTAMP('2026-08-02T23:59:59Z')
  AND destination_table.table_id = 'fact_sales_profit'
ORDER BY creation_time ASC
" || echo "region-us JOBS_BY_PROJECT недоступен либо пуст (см. rc/сообщение выше)"

echo "=== date -u (end) ==="
date -u
echo "=== gcloud auth list (end) ==="
gcloud auth list
