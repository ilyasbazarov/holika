#!/usr/bin/env bash
set -euo pipefail
date -u
gcloud auth list 2>&1

PROJECT=msklad-bi-prod

echo "=== total count of LOAD jobs to core.fact_purchases since 2026-07-27, plus actor/job_type ==="
bq query --project_id="$PROJECT" --use_legacy_sql=false --format=prettyjson "
SELECT
  COUNT(*) AS n,
  MIN(creation_time) AS first_ts,
  MAX(creation_time) AS last_ts,
  ARRAY_AGG(DISTINCT user_email IGNORE NULLS LIMIT 5) AS actors,
  ARRAY_AGG(DISTINCT job_type IGNORE NULLS LIMIT 5) AS job_types,
  ARRAY_AGG(DISTINCT statement_type IGNORE NULLS LIMIT 5) AS stmt_types
FROM \`region-asia-east1\`.INFORMATION_SCHEMA.JOBS_BY_PROJECT
WHERE creation_time >= TIMESTAMP('2026-07-27T00:00:00Z')
  AND destination_table.table_id = 'fact_purchases'
  AND destination_table.dataset_id = 'core'
"

echo "=== same for core.fact_returns ==="
bq query --project_id="$PROJECT" --use_legacy_sql=false --format=prettyjson "
SELECT
  COUNT(*) AS n,
  MIN(creation_time) AS first_ts,
  MAX(creation_time) AS last_ts,
  ARRAY_AGG(DISTINCT user_email IGNORE NULLS LIMIT 5) AS actors,
  ARRAY_AGG(DISTINCT job_type IGNORE NULLS LIMIT 5) AS job_types,
  ARRAY_AGG(DISTINCT statement_type IGNORE NULLS LIMIT 5) AS stmt_types
FROM \`region-asia-east1\`.INFORMATION_SCHEMA.JOBS_BY_PROJECT
WHERE creation_time >= TIMESTAMP('2026-07-27T00:00:00Z')
  AND destination_table.table_id = 'fact_returns'
  AND destination_table.dataset_id = 'core'
"

echo "=== sample 3 fact_purchases jobs full row ==="
bq query --project_id="$PROJECT" --use_legacy_sql=false --format=prettyjson "
SELECT creation_time, job_id, user_email, job_type, statement_type, state, error_result
FROM \`region-asia-east1\`.INFORMATION_SCHEMA.JOBS_BY_PROJECT
WHERE creation_time >= TIMESTAMP('2026-07-27T00:00:00Z')
  AND destination_table.table_id = 'fact_purchases'
  AND destination_table.dataset_id = 'core'
ORDER BY creation_time ASC
LIMIT 3
"

date -u
gcloud auth list 2>&1
