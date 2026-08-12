#!/usr/bin/env bash
set -euo pipefail

echo "=== UTC anchor (start) ==="
date -u
echo "=== gcloud auth (start) ==="
gcloud auth list

echo "=== 1) core.fact_sales_profit — по суткам, окно [today-7d; today] (Asia/Bishkek) ==="
bq query --use_legacy_sql=false --format=prettyjson "
SELECT transaction_date,
       COUNT(*) AS n_rows,
       SUM(revenue_kgs) AS total_revenue_kgs
FROM \`msklad-bi-prod.core.fact_sales_profit\`
WHERE transaction_date >= DATE_SUB(CURRENT_DATE('Asia/Bishkek'), INTERVAL 7 DAY)
  AND transaction_date <= CURRENT_DATE('Asia/Bishkek')
GROUP BY transaction_date
ORDER BY transaction_date
"

echo "=== 2) stg_msklad.fact_sales_staging — по суткам, то же окно ==="
bq query --use_legacy_sql=false --format=prettyjson "
SELECT
  DATE(PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%E3S', transaction_date_raw), 'Asia/Bishkek') AS transaction_date,
  COUNT(*) AS n_rows,
  SUM(revenue_kgs) AS total_revenue_kgs
FROM \`msklad-bi-prod.stg_msklad.fact_sales_staging\`
WHERE DATE(PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%E3S', transaction_date_raw), 'Asia/Bishkek')
      >= DATE_SUB(CURRENT_DATE('Asia/Bishkek'), INTERVAL 7 DAY)
  AND DATE(PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%E3S', transaction_date_raw), 'Asia/Bishkek')
      <= CURRENT_DATE('Asia/Bishkek')
GROUP BY transaction_date
ORDER BY transaction_date
"

echo "=== 3) расхождение живой таблицы со снимком snap_20260811_163306 (форма как в step3) ==="
bq query --use_legacy_sql=false --format=prettyjson "
SELECT COUNT(*) AS missing_from_live
FROM \`msklad-bi-prod.core.fact_sales_profit_snap_20260811_163306\` s
LEFT JOIN \`msklad-bi-prod.core.fact_sales_profit\` l USING (transaction_id)
WHERE l.transaction_id IS NULL
"

echo "=== UTC anchor (end) ==="
date -u
echo "=== gcloud auth (end) ==="
gcloud auth list
