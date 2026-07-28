#!/bin/bash
set -euo pipefail

echo "=== ANCHOR START ==="
date -u
gcloud auth list --filter=status:ACTIVE --format='value(account)'
echo "=== ANCHOR START END ==="

echo
echo "### total_sum_usd по месяцам, второй прогон staging (после интервала + промежуточного шага) ###"
bq query --use_legacy_sql=false --format=prettyjson \
"SELECT year_month, ROUND(SUM(total_sum_usd), 2) AS usd_run2, COUNT(*) AS rows_run2
FROM \`msklad-bi-prod.marts.expenses_staging\`
GROUP BY 1
ORDER BY 1"

echo
echo "=== ANCHOR END ==="
date -u
gcloud auth list --filter=status:ACTIVE --format='value(account)'
echo "=== ANCHOR END END ==="
