#!/usr/bin/env bash
set -euo pipefail
date -u
gcloud auth list 2>&1

PROJECT=msklad-bi-prod

echo "=== full detail: both fact_returns LOAD jobs since 2026-07-27 ==="
bq query --project_id="$PROJECT" --use_legacy_sql=false --format=prettyjson "
SELECT creation_time, end_time, job_id, state, error_result, total_bytes_processed
FROM \`region-asia-east1\`.INFORMATION_SCHEMA.JOBS_BY_PROJECT
WHERE creation_time >= TIMESTAMP('2026-07-27T00:00:00Z')
  AND destination_table.table_id = 'fact_returns'
  AND destination_table.dataset_id = 'core'
ORDER BY creation_time ASC
"

echo "=== current state: core.fact_purchases (freshness, row count, order_date coverage incl 08-01..08-04) ==="
bq query --project_id="$PROJECT" --use_legacy_sql=false --format=prettyjson "
SELECT MIN(order_date) AS min_d, MAX(order_date) AS max_d, COUNT(*) AS total_rows, MAX(_loaded_at) AS max_loaded_at
FROM \`$PROJECT.core.fact_purchases\`
"
bq query --project_id="$PROJECT" --use_legacy_sql=false --format=prettyjson "
SELECT order_date, COUNT(*) AS n
FROM \`$PROJECT.core.fact_purchases\`
WHERE order_date BETWEEN '2026-07-30' AND '2026-08-05'
GROUP BY order_date ORDER BY order_date
"

echo "=== current state: core.fact_returns (freshness, row count, return_date coverage incl 08-01..08-04) ==="
bq query --project_id="$PROJECT" --use_legacy_sql=false --format=prettyjson "
SELECT MIN(return_date) AS min_d, MAX(return_date) AS max_d, COUNT(*) AS total_rows, MAX(_loaded_at) AS max_loaded_at
FROM \`$PROJECT.core.fact_returns\`
"
bq query --project_id="$PROJECT" --use_legacy_sql=false --format=prettyjson "
SELECT return_date, COUNT(*) AS n
FROM \`$PROJECT.core.fact_returns\`
WHERE return_date BETWEEN '2026-07-28' AND '2026-08-05'
GROUP BY return_date ORDER BY return_date
"

echo "=== independent COUNT(*) controls (silent-truncation guard) ==="
bq query --project_id="$PROJECT" --use_legacy_sql=false --format=prettyjson "
SELECT
 (SELECT COUNT(*) FROM \`$PROJECT.core.fact_purchases\`) AS n_purchases,
 (SELECT COUNT(*) FROM \`$PROJECT.core.fact_returns\`) AS n_returns
"

date -u
gcloud auth list 2>&1
