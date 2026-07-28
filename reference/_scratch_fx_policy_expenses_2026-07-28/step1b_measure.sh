#!/bin/bash
set -euo pipefail

echo "=== ANCHOR START ==="
date -u
gcloud auth list --filter=status:ACTIVE --format='value(account)'
echo "=== ANCHOR START END ==="

echo
echo "### Уточнение: строки без курса в апреле-2025, разбивка по дате (payments) ###"
bq query --use_legacy_sql=false --format=prettyjson \
"SELECT p.moment, COUNT(*) AS rows_without_fx
FROM \`msklad-bi-prod.core.fact_payments\` p
LEFT JOIN \`msklad-bi-prod.core.dim_fx_rates\` fx ON fx.date = p.moment
WHERE p.moment IS NOT NULL AND fx.date IS NULL
  AND p.moment BETWEEN DATE '2025-04-01' AND DATE '2025-04-30'
GROUP BY 1 ORDER BY 1"

echo
echo "### Уточнение: строки без курса в апреле-2025, разбивка по дате (loss) ###"
bq query --use_legacy_sql=false --format=prettyjson \
"SELECT DATE(l.moment) AS d, COUNT(*) AS rows_without_fx
FROM \`msklad-bi-prod.core.fact_loss\` l
LEFT JOIN \`msklad-bi-prod.core.dim_fx_rates\` fx ON fx.date = DATE(l.moment)
WHERE l.moment IS NOT NULL AND fx.date IS NULL
  AND DATE(l.moment) BETWEEN DATE '2025-04-01' AND DATE '2025-04-30'
GROUP BY 1 ORDER BY 1"

echo
echo "### Уточнение: строки без курса в апреле-2025, разбивка по дате (commissionreportin) ###"
bq query --use_legacy_sql=false --format=prettyjson \
"SELECT DATE(c.moment) AS d, COUNT(*) AS rows_without_fx
FROM \`msklad-bi-prod.core.fact_commissionreportin\` c
LEFT JOIN \`msklad-bi-prod.core.dim_fx_rates\` fx ON fx.date = DATE(c.moment)
WHERE c.moment IS NOT NULL AND fx.date IS NULL
  AND DATE(c.moment) BETWEEN DATE '2025-04-01' AND DATE '2025-04-30'
GROUP BY 1 ORDER BY 1"

echo
echo "=== ANCHOR END ==="
date -u
gcloud auth list --filter=status:ACTIVE --format='value(account)'
echo "=== ANCHOR END END ==="
