#!/bin/bash
set -uo pipefail
date -u
gcloud auth list
echo "=== Q-14: JOBS_BY_PROJECT search for LOAD jobs referencing GCS raw bucket, any location ==="
for LOC in asia-east1 US; do
  echo "--- location=$LOC ---"
  bq query --use_legacy_sql=false --location="$LOC" --format=prettyjson '
  SELECT
    job_id, creation_time, user_email, statement_type, query,
    destination_table.dataset_id AS dest_dataset, destination_table.table_id AS dest_table
  FROM `msklad-bi-prod`.`region-'"$LOC"'`.INFORMATION_SCHEMA.JOBS_BY_PROJECT
  WHERE creation_time > TIMESTAMP("2024-01-01")
    AND (
      LOWER(query) LIKE "%msklad-raw-msklad-bi-prod%"
      OR LOWER(query) LIKE "%gcs%"
    )
    AND destination_table.dataset_id = "core"
  ORDER BY creation_time
  LIMIT 50'
done
date -u
gcloud auth list
