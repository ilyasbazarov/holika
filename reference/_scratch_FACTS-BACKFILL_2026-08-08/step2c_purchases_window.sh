#!/usr/bin/env bash
set -euo pipefail
date -u
gcloud auth list 2>&1

PROJECT=msklad-bi-prod

echo "=== ALL fact_purchases LOAD jobs, 2026-07-31T00:00Z..2026-08-05T00:00Z (spans the drift_check blockage 08-01T18:00Z..08-04T18:00Z) ==="
bq query --project_id="$PROJECT" --use_legacy_sql=false --format=prettyjson --max_rows=200 "
SELECT creation_time, job_id, state, error_result
FROM \`region-asia-east1\`.INFORMATION_SCHEMA.JOBS_BY_PROJECT
WHERE creation_time >= TIMESTAMP('2026-07-31T00:00:00Z')
  AND creation_time <  TIMESTAMP('2026-08-05T00:00:00Z')
  AND destination_table.table_id = 'fact_purchases'
  AND destination_table.dataset_id = 'core'
ORDER BY creation_time ASC
"

echo "=== independent COUNT(*) for same window (control) ==="
bq query --project_id="$PROJECT" --use_legacy_sql=false --format=prettyjson "
SELECT COUNT(*) AS n
FROM \`region-asia-east1\`.INFORMATION_SCHEMA.JOBS_BY_PROJECT
WHERE creation_time >= TIMESTAMP('2026-07-31T00:00:00Z')
  AND creation_time <  TIMESTAMP('2026-08-05T00:00:00Z')
  AND destination_table.table_id = 'fact_purchases'
  AND destination_table.dataset_id = 'core'
"

date -u
gcloud auth list 2>&1
