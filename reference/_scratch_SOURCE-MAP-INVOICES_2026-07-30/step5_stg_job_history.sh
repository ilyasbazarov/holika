#!/usr/bin/env bash
set -uo pipefail
date -u
gcloud auth list

PROJECT=msklad-bi-prod

bq query --use_legacy_sql=false --project_id="$PROJECT" --format=prettyjson "
SELECT job_id, user_email, creation_time, job_type, statement_type,
       destination_table.dataset_id, destination_table.table_id,
       SUBSTR(query, 1, 500) AS query_prefix
FROM \`region-asia-east1\`.INFORMATION_SCHEMA.JOBS_BY_PROJECT
WHERE destination_table.dataset_id = 'core'
  AND destination_table.table_id = 'fact_customer_invoices_stg'
ORDER BY creation_time
" 2>&1

gcloud auth list
date -u
