#!/bin/bash
set -euo pipefail

echo "=== ANCHOR START ==="
date -u
gcloud auth list --filter=status:ACTIVE --format='value(account)'
echo "=== ANCHOR START END ==="

echo
echo "### Сверка 1: май-2026 в KGS (все статьи минус Перемещение исходящий плюс Налоги и сборы) ###"
bq query --use_legacy_sql=false --format=prettyjson \
"SELECT
  ROUND(SUM(CASE WHEN expense_item_name != 'Перемещение исходящий' THEN total_sum_kgs ELSE 0 END), 2) AS may_kgs_sum
FROM \`msklad-bi-prod.marts.expenses_staging\`
WHERE year_month = '2026-05'"

echo
echo "### Сверка 2а: схема expenses_staging ###"
bq show --schema --format=prettyjson msklad-bi-prod:marts.expenses_staging

echo
echo "### Сверка 2б: схема marts.expenses (прод) ###"
bq show --schema --format=prettyjson msklad-bi-prod:marts.expenses

echo
echo "### Сверка 3: total_sum_usd за май-2026, staging vs прод ###"
bq query --use_legacy_sql=false --format=prettyjson \
"SELECT
  (SELECT ROUND(SUM(total_sum_usd), 2) FROM \`msklad-bi-prod.marts.expenses_staging\` WHERE year_month = '2026-05') AS staging_may_usd,
  (SELECT ROUND(SUM(total_sum_usd), 2) FROM \`msklad-bi-prod.marts.expenses\` WHERE year_month = '2026-05') AS prod_may_usd,
  (SELECT COUNT(*) FROM \`msklad-bi-prod.marts.expenses_staging\` WHERE year_month = '2026-05') AS staging_may_rows,
  (SELECT COUNT(*) FROM \`msklad-bi-prod.marts.expenses\` WHERE year_month = '2026-05') AS prod_may_rows"

echo
echo "### Сверка 3б: дифф USD по месяцам, staging минус прод (только месяцы с ненулевой дельтой) ###"
bq query --use_legacy_sql=false --format=prettyjson \
"WITH stg AS (
  SELECT year_month, ROUND(SUM(total_sum_usd), 2) AS usd, COUNT(*) AS rows_stg
  FROM \`msklad-bi-prod.marts.expenses_staging\` GROUP BY 1
), prod AS (
  SELECT year_month, ROUND(SUM(total_sum_usd), 2) AS usd, COUNT(*) AS rows_prod
  FROM \`msklad-bi-prod.marts.expenses\` GROUP BY 1
)
SELECT
  COALESCE(stg.year_month, prod.year_month) AS year_month,
  stg.usd AS staging_usd,
  prod.usd AS prod_usd,
  ROUND(stg.usd - prod.usd, 2) AS delta_usd,
  stg.rows_stg,
  prod.rows_prod
FROM stg
FULL OUTER JOIN prod USING (year_month)
ORDER BY year_month"

echo
echo "=== ANCHOR END ==="
date -u
gcloud auth list --filter=status:ACTIVE --format='value(account)'
echo "=== ANCHOR END END ==="
