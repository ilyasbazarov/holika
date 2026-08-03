#!/usr/bin/env bash
set -euo pipefail
date -u
gcloud auth list 2>&1

PROJECT=msklad-bi-prod

echo "=== MERGE jobs targeting core.fact_sales_profit since 2026-08-03T17:00:00Z (asia-east1) ==="
bq query --project_id="$PROJECT" --use_legacy_sql=false --format=prettyjson --max_rows=1000 "
SELECT
  job_id,
  creation_time,
  user_email,
  state,
  statement_type,
  destination_table.dataset_id AS dst_dataset,
  destination_table.table_id AS dst_table
FROM \`region-asia-east1\`.INFORMATION_SCHEMA.JOBS_BY_PROJECT
WHERE creation_time >= TIMESTAMP('2026-08-03T17:00:00Z')
  AND destination_table.table_id = 'fact_sales_profit'
ORDER BY creation_time ASC
"

echo "=== independent COUNT(*) of same set ==="
bq query --project_id="$PROJECT" --use_legacy_sql=false --format=prettyjson "
SELECT COUNT(*) AS n
FROM \`region-asia-east1\`.INFORMATION_SCHEMA.JOBS_BY_PROJECT
WHERE creation_time >= TIMESTAMP('2026-08-03T17:00:00Z')
  AND destination_table.table_id = 'fact_sales_profit'
"

date -u
gcloud auth list 2>&1
