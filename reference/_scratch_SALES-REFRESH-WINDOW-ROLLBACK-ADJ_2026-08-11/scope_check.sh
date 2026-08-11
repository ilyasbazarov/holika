#!/usr/bin/env bash
set -u
P=msklad-bi-prod
echo "=== ЯКОРЬ НАЧАЛА ==="; date -u; gcloud auth list 2>&1 | head -4; echo
echo "=== Состав core.fact_sales_profit по происхождению строк, окно 90 суток ==="
bq query --project_id=$P --use_legacy_sql=false --format=prettyjson -n 20 '
SELECT
  entity_type,
  COALESCE(sales_channel_name,"(NULL)") AS channel,
  COUNT(*)                    AS n_rows,
  ROUND(SUM(revenue_kgs),2)   AS revenue_kgs
FROM `msklad-bi-prod.core.fact_sales_profit`
WHERE transaction_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY)
GROUP BY entity_type, channel
ORDER BY n_rows DESC'
echo
echo "=== Что лежит в staging периметра (источник второго MERGE) ==="
bq query --project_id=$P --use_legacy_sql=false --format=prettyjson -n 20 '
SELECT entity_type, COUNT(*) AS n_rows
FROM `msklad-bi-prod.stg_msklad.fact_sales_perimeter_staging`
GROUP BY entity_type ORDER BY n_rows DESC'
echo "=== ЯКОРЬ КОНЦА ==="; date -u; gcloud auth list 2>&1 | head -4
