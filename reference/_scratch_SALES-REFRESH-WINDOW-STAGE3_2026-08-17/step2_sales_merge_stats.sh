#!/usr/bin/env bash
set -euo pipefail

echo "=== UTC anchor (start) ==="
date -u
echo "=== gcloud auth (start) ==="
gcloud auth list

echo "=== BigQuery job history: MERGE jobs into fact_sales_profit since 2026-08-16T00:50:00Z ==="
bq query --use_legacy_sql=false --format=prettyjson "
SELECT
  job_id,
  creation_time,
  end_time,
  dml_statistics.inserted_row_count AS inserted,
  dml_statistics.deleted_row_count AS deleted,
  dml_statistics.updated_row_count AS updated
FROM \`msklad-bi-prod\`.\`region-asia-east1\`.INFORMATION_SCHEMA.JOBS_BY_PROJECT
WHERE creation_time >= TIMESTAMP('2026-08-16T00:50:00Z')
  AND statement_type = 'MERGE'
  AND REGEXP_CONTAINS(query, r'fact_sales_profit')
ORDER BY creation_time
"

echo "=== BigQuery job history: any MERGE into perimeter table since 2026-08-16T00:50:00Z (expect none — guard tripped) ==="
bq query --use_legacy_sql=false --format=prettyjson "
SELECT
  job_id,
  creation_time,
  dml_statistics.inserted_row_count AS inserted,
  dml_statistics.deleted_row_count AS deleted,
  dml_statistics.updated_row_count AS updated
FROM \`msklad-bi-prod\`.\`region-asia-east1\`.INFORMATION_SCHEMA.JOBS_BY_PROJECT
WHERE creation_time >= TIMESTAMP('2026-08-16T00:50:00Z')
  AND statement_type = 'MERGE'
  AND NOT REGEXP_CONTAINS(query, r'fact_sales_profit')
ORDER BY creation_time
"

echo "=== core.fact_sales_profit — May 2026 totals, current state ==="
bq query --use_legacy_sql=false --format=prettyjson "
SELECT COUNT(*) AS n_rows, SUM(revenue_kgs) AS total_revenue_kgs
FROM \`msklad-bi-prod.core.fact_sales_profit\`
WHERE transaction_date BETWEEN '2026-05-01' AND '2026-05-31'
"

echo "=== core.fact_sales_profit vs snap_20260811_163306 — current diff (row count only, same method as scope_verify) ==="
bq query --use_legacy_sql=false --format=prettyjson "
SELECT
  (SELECT COUNT(*) FROM \`msklad-bi-prod.core.fact_sales_profit_snap_20260811_163306\`) AS snap_rows,
  (SELECT COUNT(*) FROM \`msklad-bi-prod.core.fact_sales_profit\`) AS live_rows
"

echo "=== UTC anchor (end) ==="
date -u
echo "=== gcloud auth (end) ==="
gcloud auth list
