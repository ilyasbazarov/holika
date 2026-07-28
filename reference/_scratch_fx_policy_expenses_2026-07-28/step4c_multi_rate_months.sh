#!/bin/bash
set -euo pipefail

echo "=== ANCHOR START ==="
date -u
gcloud auth list --filter=status:ACTIVE --format='value(account)'
echo "=== ANCHOR START END ==="

echo
echo "### Месяцы, где core.dim_fx_rates несёт больше одного значения курса ###"
bq query --use_legacy_sql=false --format=prettyjson \
"SELECT
  FORMAT_DATE('%Y-%m', date) AS year_month,
  COUNT(DISTINCT rate_kgs_per_usd) AS distinct_rates
FROM \`msklad-bi-prod.core.dim_fx_rates\`
GROUP BY 1
HAVING COUNT(DISTINCT rate_kgs_per_usd) > 1
ORDER BY 1"

echo
echo "=== ANCHOR END ==="
date -u
gcloud auth list --filter=status:ACTIVE --format='value(account)'
echo "=== ANCHOR END END ==="
