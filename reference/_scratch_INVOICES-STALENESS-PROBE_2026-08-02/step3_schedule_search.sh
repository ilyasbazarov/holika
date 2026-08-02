#!/usr/bin/env bash
set -euo pipefail

echo "=== date -u (start) ==="
date -u

echo "=== gcloud auth list (start) ==="
gcloud auth list

PROJECT="msklad-bi-prod"

echo "=== bq ls --transfer_config --transfer_location=asia-east1 ==="
bq ls --transfer_config --transfer_location=asia-east1 --project_id="${PROJECT}" 2>&1 || echo "RC_NONZERO_asia-east1=$?"

echo "=== bq ls --transfer_config --transfer_location=us ==="
bq ls --transfer_config --transfer_location=us --project_id="${PROJECT}" 2>&1 || echo "RC_NONZERO_us=$?"

echo "=== JOBS_BY_PROJECT (region-asia-east1) mentioning fact_customer_invoices, last 90 days ==="
bq query --project_id="${PROJECT}" --use_legacy_sql=false --format=prettyjson '
SELECT
  creation_time,
  job_id,
  user_email,
  statement_type,
  destination_table.dataset_id AS dst_dataset,
  destination_table.table_id AS dst_table,
  state,
  error_result.message AS error_message
FROM `msklad-bi-prod`.`region-asia-east1`.INFORMATION_SCHEMA.JOBS_BY_PROJECT
WHERE creation_time >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 90 DAY)
  AND (
    LOWER(query) LIKE "%fact_customer_invoices%"
    OR destination_table.table_id = "fact_customer_invoices"
  )
ORDER BY creation_time DESC
' | tee jobs_asia_east1_90d.json

echo "=== JOBS_BY_PROJECT (region-us) mentioning fact_customer_invoices, last 90 days ==="
bq query --project_id="${PROJECT}" --use_legacy_sql=false --format=prettyjson '
SELECT
  creation_time,
  job_id,
  user_email,
  statement_type,
  destination_table.dataset_id AS dst_dataset,
  destination_table.table_id AS dst_table,
  state,
  error_result.message AS error_message
FROM `msklad-bi-prod`.`region-us`.INFORMATION_SCHEMA.JOBS_BY_PROJECT
WHERE creation_time >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 90 DAY)
  AND (
    LOWER(query) LIKE "%fact_customer_invoices%"
    OR destination_table.table_id = "fact_customer_invoices"
  )
ORDER BY creation_time DESC
' | tee jobs_us_90d.json

echo "=== JOBS_BY_PROJECT (region-asia-east1) ALL jobs writing to core dataset, last 7 days (sanity: is anything running at all recently) ==="
bq query --project_id="${PROJECT}" --use_legacy_sql=false --format=prettyjson '
SELECT
  creation_time, job_id, user_email, destination_table.dataset_id AS dst_dataset, destination_table.table_id AS dst_table, state
FROM `msklad-bi-prod`.`region-asia-east1`.INFORMATION_SCHEMA.JOBS_BY_PROJECT
WHERE creation_time >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)
  AND destination_table.dataset_id = "core"
ORDER BY creation_time DESC
LIMIT 50
' | tee jobs_asia_east1_core_7d.json

echo "=== date -u (end) ==="
date -u

echo "=== gcloud auth list (end) ==="
gcloud auth list

echo "=== ARTIFACT DIR ==="
pwd
