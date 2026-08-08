#!/usr/bin/env bash
set -euo pipefail
echo "=== date -u ==="
date -u
echo "=== staging table state for retry2 run_id ==="
bq query --use_legacy_sql=false --format=pretty \
"SELECT COUNT(*) AS row_count, MIN(transaction_date_raw) AS min_date, MAX(transaction_date_raw) AS max_date, MAX(_loaded_at) AS max_loaded_at, COUNTIF(document_owner_employee_id IS NOT NULL) AS with_owner
 FROM \`msklad-bi-prod.stg_msklad.fact_sales_staging\`
 WHERE run_id = 'verify_deploy_2026-08-08_document_owner_weekly_retry2'"
echo "=== current run_id present in staging (any) ==="
bq query --use_legacy_sql=false --format=pretty \
"SELECT run_id, COUNT(*) AS row_count, MAX(_loaded_at) AS max_loaded_at
 FROM \`msklad-bi-prod.stg_msklad.fact_sales_staging\`
 GROUP BY run_id ORDER BY max_loaded_at DESC LIMIT 3"
