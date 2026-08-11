#!/usr/bin/env bash
# SALES-REFRESH-WINDOW-MANDATE-ADJ · шаг 1 · факты под три решения архитектора.
# Класс A: только чтение. Ни MERGE, ни promote, ни деплоя.
# ADR-055/063: date -u и gcloud auth list — первой И последней командой.
set -u
P=msklad-bi-prod

echo "=== ЯКОРЬ НАЧАЛА ==="; date -u; gcloud auth list 2>&1 | head -4; echo

echo "=== A. Глубина time travel датасета core (вопрос отката, ADR-145 §5) ==="
bq show --project_id=$P --format=prettyjson $P:core 2>&1 | grep -i "maxTimeTravel\|defaultTableExpiration\|location"
echo

echo "=== B. Предикат предохранителя, реплика read-only, обе живые staging ==="
echo "--- B1: staging продаж, что покрывает по датам ---"
bq query --project_id=$P --use_legacy_sql=false --format=prettyjson -n 5 '
SELECT
  MIN(DATE(PARSE_TIMESTAMP("%Y-%m-%d %H:%M:%E3S", transaction_date_raw), "Asia/Bishkek")) AS min_date,
  MAX(DATE(PARSE_TIMESTAMP("%Y-%m-%d %H:%M:%E3S", transaction_date_raw), "Asia/Bishkek")) AS max_date,
  COUNT(*) AS n_rows,
  DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)  AS window_start_7,
  DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY) AS window_start_90
FROM `msklad-bi-prod.stg_msklad.fact_sales_staging`'
echo
echo "--- B2: staging периметра, то же ---"
bq query --project_id=$P --use_legacy_sql=false --format=prettyjson -n 5 '
SELECT
  MIN(DATE(PARSE_TIMESTAMP("%Y-%m-%d %H:%M:%E3S", transaction_date_raw), "Asia/Bishkek")) AS min_date,
  MAX(DATE(PARSE_TIMESTAMP("%Y-%m-%d %H:%M:%E3S", transaction_date_raw), "Asia/Bishkek")) AS max_date,
  COUNT(*) AS n_rows
FROM `msklad-bi-prod.stg_msklad.fact_sales_perimeter_staging`'
echo

echo "=== C. Цена ложного отказа: сколько суток БЕЗ продаж и бывают ли подряд ==="
echo "(вход в решение о допуске; окно — последние 180 суток ядра)"
bq query --project_id=$P --use_legacy_sql=false --format=prettyjson -n 5 '
WITH d AS (
  SELECT day FROM UNNEST(GENERATE_DATE_ARRAY(
    DATE_SUB(CURRENT_DATE(), INTERVAL 180 DAY), CURRENT_DATE())) AS day
),
rev AS (
  SELECT transaction_date AS day, SUM(revenue_kgs) AS r
  FROM `msklad-bi-prod.core.fact_sales_profit`
  WHERE transaction_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 180 DAY)
  GROUP BY 1
),
j AS (SELECT d.day, IFNULL(rev.r, 0) AS r FROM d LEFT JOIN rev USING (day)),
runs AS (
  SELECT day, r,
         COUNTIF(r > 0) OVER (ORDER BY day ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS nonzero_in_3
  FROM j
)
SELECT
  COUNT(*)                                   AS days_total,
  COUNTIF(r = 0)                             AS days_zero,
  ROUND(100 * COUNTIF(r = 0) / COUNT(*), 2)  AS pct_zero,
  COUNTIF(nonzero_in_3 = 0)                  AS windows_3d_all_zero
FROM runs'
echo

echo "=== ЯКОРЬ КОНЦА ==="; date -u; gcloud auth list 2>&1 | head -4
