#!/usr/bin/env bash
set -euo pipefail
echo "=== date -u ==="
date -u
echo "=== May 2026, core.fact_sales_profit, BEFORE weekly run ==="
bq query --use_legacy_sql=false --format=pretty \
"SELECT COUNT(*) AS row_count, ROUND(SUM(revenue_kgs), 2) AS revenue_kgs_sum
 FROM \`msklad-bi-prod.core.fact_sales_profit\`
 WHERE transaction_date BETWEEN '2026-05-01' AND '2026-05-31'"
echo "=== July 2026, core.fact_sales_profit, document_owner_employee_id filled — BEFORE weekly run ==="
bq query --use_legacy_sql=false --format=pretty \
"SELECT COUNT(*) AS total_july, COUNTIF(document_owner_employee_id IS NOT NULL) AS with_owner_july
 FROM \`msklad-bi-prod.core.fact_sales_profit\`
 WHERE transaction_date BETWEEN '2026-07-01' AND '2026-07-31'"
