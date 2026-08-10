#!/usr/bin/env bash
set -euo pipefail
date -u
gcloud auth list 2>&1

PROJECT=msklad-bi-prod

echo "=== LOAD jobs targeting core.fact_purchases, 2026-07-27T00:00:00Z..now ==="
bq query --project_id="$PROJECT" --use_legacy_sql=false --format=prettyjson --max_rows=1000 "
SELECT
  creation_time,
  end_time,
  job_id,
  state,
  error_result,
  destination_table.dataset_id AS dest_dataset,
  destination_table.table_id AS dest_table,
  total_bytes_processed
FROM \`region-asia-east1\`.INFORMATION_SCHEMA.JOBS_BY_PROJECT
WHERE creation_time >= TIMESTAMP('2026-07-27T00:00:00Z')
  AND destination_table.table_id = 'fact_purchases'
  AND destination_table.dataset_id = 'core'
ORDER BY creation_time ASC
"

echo "=== LOAD jobs targeting core.fact_returns, 2026-07-27T00:00:00Z..now ==="
bq query --project_id="$PROJECT" --use_legacy_sql=false --format=prettyjson --max_rows=1000 "
SELECT
  creation_time,
  end_time,
  job_id,
  state,
  error_result,
  destination_table.dataset_id AS dest_dataset,
  destination_table.table_id AS dest_table,
  total_bytes_processed
FROM \`region-asia-east1\`.INFORMATION_SCHEMA.JOBS_BY_PROJECT
WHERE creation_time >= TIMESTAMP('2026-07-27T00:00:00Z')
  AND destination_table.table_id = 'fact_returns'
  AND destination_table.dataset_id = 'core'
ORDER BY creation_time ASC
"

echo "=== independent COUNT(*) sanity: any jobs at all targeting core.* since 2026-07-27 (control for silent truncation of above) ==="
bq query --project_id="$PROJECT" --use_legacy_sql=false --format=prettyjson "
SELECT destination_table.table_id AS dest_table, COUNT(*) AS n_jobs
FROM \`region-asia-east1\`.INFORMATION_SCHEMA.JOBS_BY_PROJECT
WHERE creation_time >= TIMESTAMP('2026-07-27T00:00:00Z')
  AND destination_table.dataset_id = 'core'
GROUP BY dest_table
ORDER BY dest_table
"

date -u
gcloud auth list 2>&1
