#!/usr/bin/env bash
set -euo pipefail
echo "=== date -u ==="
date -u
echo "=== staging check ==="
bq query --use_legacy_sql=false --format=pretty \
"SELECT COUNT(*) AS total, COUNTIF(document_owner_employee_id IS NOT NULL) AS with_owner, COUNTIF(document_owner_employee_id IS NULL) AS without_owner
 FROM \`msklad-bi-prod.stg_msklad.fact_sales_staging\`
 WHERE run_id = 'verify_deploy_2026-08-08_document_owner_hourly'"
