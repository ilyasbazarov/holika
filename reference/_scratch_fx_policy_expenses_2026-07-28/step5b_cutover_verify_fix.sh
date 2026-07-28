#!/bin/bash
set -euo pipefail

echo "=== ANCHOR START ==="
date -u
gcloud auth list --filter=status:ACTIVE --format='value(account)'
echo "=== ANCHOR START END ==="

echo
echo "### (1) Автоматический прогон sq_marts_expenses сегодня, регион asia-east1 ###"
bq query --use_legacy_sql=false --location=asia-east1 --format=prettyjson \
"SELECT
  job_id,
  creation_time,
  end_time,
  state,
  error_result,
  user_email
FROM \`msklad-bi-prod.asia-east1\`.INFORMATION_SCHEMA.JOBS_BY_PROJECT
WHERE creation_time BETWEEN TIMESTAMP '2026-07-28 10:30:00 UTC' AND TIMESTAMP '2026-07-28 12:00:00 UTC'
  AND destination_table.dataset_id = 'marts'
  AND destination_table.table_id = 'expenses'
ORDER BY creation_time"

echo
echo "### (1б) Контроль: все задания с целью marts.expenses за 13-28 июля, регион asia-east1 (сверка со старым замером — было 16) ###"
bq query --use_legacy_sql=false --location=asia-east1 --format=prettyjson \
"SELECT COUNT(*) AS total_jobs
FROM \`msklad-bi-prod.asia-east1\`.INFORMATION_SCHEMA.JOBS_BY_PROJECT
WHERE creation_time >= TIMESTAMP '2026-07-13 00:00:00 UTC'
  AND destination_table.dataset_id = 'marts'
  AND destination_table.table_id = 'expenses'"

echo
echo "=== ANCHOR END ==="
date -u
gcloud auth list --filter=status:ACTIVE --format='value(account)'
echo "=== ANCHOR END END ==="
