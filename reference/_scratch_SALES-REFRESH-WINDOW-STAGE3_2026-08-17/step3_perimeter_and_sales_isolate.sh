#!/usr/bin/env bash
set -euo pipefail

echo "=== UTC anchor (start) ==="
date -u
echo "=== gcloud auth (start) ==="
gcloud auth list

echo "=== jobs whose query text mentions fact_sales_perimeter_staging, since 2026-08-16T00:50:00Z (perimeter promote attempts) ==="
bq query --use_legacy_sql=false --format=prettyjson "
SELECT
  job_id,
  creation_time,
  end_time,
  statement_type,
  error_result.reason AS error_reason,
  error_result.message AS error_message,
  dml_statistics.inserted_row_count AS inserted,
  dml_statistics.deleted_row_count AS deleted,
  dml_statistics.updated_row_count AS updated
FROM \`msklad-bi-prod\`.\`region-asia-east1\`.INFORMATION_SCHEMA.JOBS_BY_PROJECT
WHERE creation_time >= TIMESTAMP('2026-08-16T00:50:00Z')
  AND REGEXP_CONTAINS(query, r'fact_sales_perimeter_staging')
ORDER BY creation_time
"

echo "=== isolate the ONE weekly-run sales MERGE (90-day window): jobs between 01:00Z and 01:19Z on 2026-08-16 touching fact_sales_profit, with error info ==="
bq query --use_legacy_sql=false --format=prettyjson "
SELECT
  job_id,
  creation_time,
  end_time,
  statement_type,
  error_result.reason AS error_reason,
  dml_statistics.inserted_row_count AS inserted,
  dml_statistics.deleted_row_count AS deleted,
  dml_statistics.updated_row_count AS updated
FROM \`msklad-bi-prod\`.\`region-asia-east1\`.INFORMATION_SCHEMA.JOBS_BY_PROJECT
WHERE creation_time BETWEEN TIMESTAMP('2026-08-16T01:00:00Z') AND TIMESTAMP('2026-08-16T01:19:00Z')
  AND REGEXP_CONTAINS(query, r'fact_sales_profit')
  AND NOT REGEXP_CONTAINS(query, r'fact_sales_perimeter_staging')
ORDER BY creation_time
"

echo "=== staging coverage: MAX(transaction_date) in fact_sales_perimeter_staging as of now ==="
bq query --use_legacy_sql=false --format=prettyjson "
SELECT MIN(transaction_date) AS min_date, MAX(transaction_date) AS max_date, COUNT(*) AS n_rows
FROM \`msklad-bi-prod.stg_msklad.fact_sales_perimeter_staging\`
"

echo "=== UTC anchor (end) ==="
date -u
echo "=== gcloud auth (end) ==="
gcloud auth list
