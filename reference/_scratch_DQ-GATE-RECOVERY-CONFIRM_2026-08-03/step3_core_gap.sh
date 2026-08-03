#!/usr/bin/env bash
set -euo pipefail
date -u
gcloud auth list 2>&1

PROJECT=msklad-bi-prod

echo "=== core.fact_sales_profit: MIN/MAX(transaction_date), rows by day 08-01..08-04 ==="
bq query --project_id="$PROJECT" --use_legacy_sql=false --format=prettyjson "
SELECT MIN(transaction_date) AS min_d, MAX(transaction_date) AS max_d, COUNT(*) AS total_rows
FROM \`$PROJECT.core.fact_sales_profit\`
"
bq query --project_id="$PROJECT" --use_legacy_sql=false --format=prettyjson --max_rows=1000 "
SELECT transaction_date, COUNT(*) AS n_rows
FROM \`$PROJECT.core.fact_sales_profit\`
WHERE transaction_date BETWEEN DATE('2026-08-01') AND DATE('2026-08-04')
GROUP BY 1 ORDER BY 1
"

echo "=== core.fact_purchases: MIN/MAX(transaction_date), rows by day 08-01..08-04 ==="
bq query --project_id="$PROJECT" --use_legacy_sql=false --format=prettyjson "
SELECT MIN(transaction_date) AS min_d, MAX(transaction_date) AS max_d, COUNT(*) AS total_rows
FROM \`$PROJECT.core.fact_purchases\`
"
bq query --project_id="$PROJECT" --use_legacy_sql=false --format=prettyjson --max_rows=1000 "
SELECT transaction_date, COUNT(*) AS n_rows
FROM \`$PROJECT.core.fact_purchases\`
WHERE transaction_date BETWEEN DATE('2026-08-01') AND DATE('2026-08-04')
GROUP BY 1 ORDER BY 1
"

date -u
gcloud auth list 2>&1
