#!/usr/bin/env bash
set -euo pipefail
PROJECT=msklad-bi-prod

echo "=== якорь начала ==="
date -u
gcloud auth list --project="$PROJECT" 2>&1 | head -10

echo
echo "=== (1) окно наблюдения: MAX(_mart_refreshed_at) marts.sales_overview, MAX(_loaded_at) core.fact_sales_profit ==="
bq query --project_id="$PROJECT" --use_legacy_sql=false --format=prettyjson -n 100 '
SELECT
  (SELECT MAX(_mart_refreshed_at) FROM `msklad-bi-prod.marts.sales_overview`) AS mart_refreshed_at,
  (SELECT MAX(_loaded_at) FROM `msklad-bi-prod.core.fact_sales_profit`) AS core_loaded_at
'

echo
echo "=== (2) core.fact_sales_profit июль-2026: COUNT(*), SUM(revenue_kgs) ==="
bq query --project_id="$PROJECT" --use_legacy_sql=false --format=prettyjson -n 100 '
SELECT COUNT(*) AS cnt, SUM(revenue_kgs) AS sum_revenue_kgs
FROM `msklad-bi-prod.core.fact_sales_profit`
WHERE transaction_date BETWEEN "2026-07-01" AND "2026-07-31"
'

echo
echo "=== (3) marts.sales_overview июль-2026: COUNT(*), SUM(revenue_kgs) ==="
bq query --project_id="$PROJECT" --use_legacy_sql=false --format=prettyjson -n 100 '
SELECT COUNT(*) AS cnt, SUM(revenue_kgs) AS sum_revenue_kgs
FROM `msklad-bi-prod.marts.sales_overview`
WHERE transaction_date BETWEEN "2026-07-01" AND "2026-07-31"
'

echo
echo "=== (4) stg_msklad.fact_sales_perimeter_staging: помесячный разрез по source_doc_type ==="
bq query --project_id="$PROJECT" --use_legacy_sql=false --format=prettyjson -n 10000 '
SELECT
  FORMAT_DATE("%Y-%m", DATE(PARSE_TIMESTAMP("%Y-%m-%d %H:%M:%E3S", transaction_date_raw), "Asia/Bishkek")) AS month,
  source_doc_type,
  COUNT(*) AS cnt,
  SUM(revenue_kgs) AS sum_revenue_kgs
FROM `msklad-bi-prod.stg_msklad.fact_sales_perimeter_staging`
GROUP BY month, source_doc_type
ORDER BY month, source_doc_type
'

echo
echo "=== (5) marts.sales_overview июль-2026: разрез по sales_channel_name ==="
bq query --project_id="$PROJECT" --use_legacy_sql=false --format=prettyjson -n 1000 '
SELECT sales_channel_name, COUNT(*) AS cnt, SUM(revenue_kgs) AS sum_revenue_kgs
FROM `msklad-bi-prod.marts.sales_overview`
WHERE transaction_date BETWEEN "2026-07-01" AND "2026-07-31"
GROUP BY sales_channel_name
ORDER BY sum_revenue_kgs DESC
'

echo
echo "=== (6) marts.sales_overview июль-2026: разрез по manager_name ==="
bq query --project_id="$PROJECT" --use_legacy_sql=false --format=prettyjson -n 1000 '
SELECT manager_name, COUNT(*) AS cnt, SUM(revenue_kgs) AS sum_revenue_kgs
FROM `msklad-bi-prod.marts.sales_overview`
WHERE transaction_date BETWEEN "2026-07-01" AND "2026-07-31"
GROUP BY manager_name
ORDER BY sum_revenue_kgs DESC
'

echo
echo "=== якорь конца ==="
date -u
gcloud auth list --project="$PROJECT" 2>&1 | head -10
