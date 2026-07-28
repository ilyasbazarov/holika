#!/bin/bash
set -euo pipefail

echo "=== ANCHOR START ==="
date -u
gcloud auth list --filter=status:ACTIVE --format='value(account)'
echo "=== ANCHOR START END ==="

echo
echo "### (1) Автоматический прогон sq_marts_expenses сегодня, слот ~11:10 UTC ###"
bq query --use_legacy_sql=false --format=prettyjson \
"SELECT
  job_id,
  creation_time,
  end_time,
  state,
  error_result
FROM \`msklad-bi-prod.region-us\`.INFORMATION_SCHEMA.JOBS_BY_PROJECT
WHERE creation_time BETWEEN TIMESTAMP '2026-07-28 10:30:00 UTC' AND TIMESTAMP '2026-07-28 12:00:00 UTC'
  AND destination_table.dataset_id = 'marts'
  AND destination_table.table_id = 'expenses'
ORDER BY creation_time"

echo
echo "### (2) Май-2026 на проде (marts.expenses) против эталона 10 232 903,20 ###"
bq query --use_legacy_sql=false --format=prettyjson \
"SELECT
  ROUND(SUM(CASE WHEN expense_item_name != 'Перемещение исходящий' THEN total_sum_kgs ELSE 0 END), 2) AS may_kgs_sum,
  ROUND(SUM(CASE WHEN expense_item_name != 'Перемещение исходящий' THEN total_sum_kgs ELSE 0 END), 2) - 10232903.20 AS gap_vs_oracle
FROM \`msklad-bi-prod.marts.expenses\`
WHERE year_month = '2026-05'"

echo
echo "=== ANCHOR END ==="
date -u
gcloud auth list --filter=status:ACTIVE --format='value(account)'
echo "=== ANCHOR END END ==="
