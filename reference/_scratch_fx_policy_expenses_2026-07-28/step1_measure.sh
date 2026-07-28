#!/bin/bash
set -euo pipefail

echo "=== ANCHOR START ==="
date -u
gcloud auth list --filter=status:ACTIVE --format='value(account)'
echo "=== ANCHOR START END ==="

echo
echo "### Замер 1: курс на последнюю дату таблицы core.dim_fx_rates ###"
bq query --use_legacy_sql=false --format=prettyjson \
"SELECT date, rate_kgs_per_usd
FROM \`msklad-bi-prod.core.dim_fx_rates\`
ORDER BY date DESC
LIMIT 1"

echo
echo "### Замер 2: MIN(moment) по core.fact_payments против 2025-04-29 ###"
bq query --use_legacy_sql=false --format=prettyjson \
"SELECT
  MIN(moment) AS min_moment,
  DATE '2025-04-29' AS fx_min_date,
  COUNTIF(moment < DATE '2025-04-29') AS payments_before_fx_min_date
FROM \`msklad-bi-prod.core.fact_payments\`"

echo
echo "### Замер 3а: core.fact_payments — строки без курса на свою дату, по году-месяцу ###"
bq query --use_legacy_sql=false --format=prettyjson \
"SELECT
  FORMAT_DATE('%Y-%m', p.moment) AS year_month,
  COUNT(*) AS rows_without_fx
FROM \`msklad-bi-prod.core.fact_payments\` p
LEFT JOIN \`msklad-bi-prod.core.dim_fx_rates\` fx
  ON fx.date = p.moment
WHERE p.moment IS NOT NULL
  AND fx.date IS NULL
GROUP BY 1
ORDER BY 1"

echo
echo "### Замер 3б: core.fact_loss — строки без курса на свою дату, по году-месяцу ###"
bq query --use_legacy_sql=false --format=prettyjson \
"SELECT
  FORMAT_DATE('%Y-%m', DATE(l.moment)) AS year_month,
  COUNT(*) AS rows_without_fx
FROM \`msklad-bi-prod.core.fact_loss\` l
LEFT JOIN \`msklad-bi-prod.core.dim_fx_rates\` fx
  ON fx.date = DATE(l.moment)
WHERE l.moment IS NOT NULL
  AND fx.date IS NULL
GROUP BY 1
ORDER BY 1"

echo
echo "### Замер 3в: core.fact_commissionreportin — строки без курса на свою дату, по году-месяцу ###"
bq query --use_legacy_sql=false --format=prettyjson \
"SELECT
  FORMAT_DATE('%Y-%m', DATE(c.moment)) AS year_month,
  COUNT(*) AS rows_without_fx
FROM \`msklad-bi-prod.core.fact_commissionreportin\` c
LEFT JOIN \`msklad-bi-prod.core.dim_fx_rates\` fx
  ON fx.date = DATE(c.moment)
WHERE c.moment IS NOT NULL
  AND fx.date IS NULL
GROUP BY 1
ORDER BY 1"

echo
echo "=== ANCHOR END ==="
date -u
gcloud auth list --filter=status:ACTIVE --format='value(account)'
echo "=== ANCHOR END END ==="
