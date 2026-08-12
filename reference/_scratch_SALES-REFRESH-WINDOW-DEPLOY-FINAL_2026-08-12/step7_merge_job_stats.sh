#!/usr/bin/env bash
set -euo pipefail

echo "=== UTC anchor (start) ==="
date -u
echo "=== gcloud auth (start) ==="
gcloud auth list

echo "=== BigQuery job history: MERGE jobs into fact_sales_profit since 18:00Z ==="
bq query --use_legacy_sql=false --format=prettyjson "
SELECT
  job_id,
  creation_time,
  query,
  dml_statistics.inserted_row_count AS inserted,
  dml_statistics.deleted_row_count AS deleted,
  dml_statistics.updated_row_count AS updated
FROM \`msklad-bi-prod\`.\`region-asia-east1\`.INFORMATION_SCHEMA.JOBS_BY_PROJECT
WHERE creation_time >= TIMESTAMP('2026-08-12T18:00:00Z')
  AND statement_type = 'MERGE'
  AND REGEXP_CONTAINS(query, r'fact_sales_profit')
ORDER BY creation_time
"

echo "=== core.fact_sales_profit — 2026-08-12, after this run (compare vs step6 baseline: 27 rows / 1054231.43) ==="
bq query --use_legacy_sql=false --format=prettyjson "
SELECT COUNT(*) AS n_rows, SUM(revenue_kgs) AS total_revenue_kgs
FROM \`msklad-bi-prod.core.fact_sales_profit\`
WHERE transaction_date = '2026-08-12'
"

echo "=== UTC anchor (end) ==="
date -u
echo "=== gcloud auth (end) ==="
gcloud auth list
