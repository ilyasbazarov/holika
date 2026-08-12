#!/usr/bin/env bash
set -euo pipefail
echo "=== date -u (start) ==="
date -u
echo "=== gcloud auth list (start) ==="
gcloud auth list
echo "=== CREATE SNAPSHOT ==="
bq query --use_legacy_sql=false --project_id=msklad-bi-prod   'CREATE SNAPSHOT TABLE `msklad-bi-prod.core.fact_sales_profit_snap_20260811_163306` CLONE `msklad-bi-prod.core.fact_sales_profit`'
echo "=== число строк / SUM(revenue_kgs) по каналам, снимок ==="
bq query --use_legacy_sql=false --project_id=msklad-bi-prod --format=prettyjson   'SELECT
     CASE
       WHEN sales_channel_name = "Оптовая торговля" THEN "оптовая торговля"
       WHEN sales_channel_name = "Комиссия" THEN "комиссия"
       WHEN sales_channel_name = "Розница" THEN "розница"
       WHEN sales_channel_name IS NULL THEN "без канала"
       ELSE sales_channel_name
     END AS channel_bucket,
     COUNT(*) AS cnt,
     SUM(revenue_kgs) AS sum_revenue_kgs
   FROM `msklad-bi-prod.core.fact_sales_profit_snap_20260811_163306`
   GROUP BY channel_bucket
   ORDER BY channel_bucket'
echo "=== число строк / сумма — итог ==="
bq query --use_legacy_sql=false --project_id=msklad-bi-prod --format=prettyjson   'SELECT COUNT(*) AS cnt, SUM(revenue_kgs) AS sum_revenue_kgs
   FROM `msklad-bi-prod.core.fact_sales_profit_snap_20260811_163306`'
echo "=== gcloud auth list (end) ==="
gcloud auth list
echo "=== date -u (end) ==="
date -u
