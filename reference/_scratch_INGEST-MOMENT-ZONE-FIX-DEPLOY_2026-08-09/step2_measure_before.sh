#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

echo "=== date -u (start) ==="
date -u
echo "=== gcloud auth list (start) ==="
gcloud auth list

echo "=== Условие 1: fact_loss / fact_commissionreportin — строки в полосе TIME(moment)>=18:00 UTC и разность месячных сумм ==="
bq query --use_legacy_sql=false --format=prettyjson '
WITH u AS (
  SELECT "loss" AS source_name, moment, sum_kgs FROM `msklad-bi-prod.core.fact_loss` WHERE applicable
  UNION ALL
  SELECT "commission" AS source_name, moment, sum_kgs FROM `msklad-bi-prod.core.fact_commissionreportin`
)
SELECT
  source_name,
  COUNTIF(TIME(moment) >= TIME(18,0,0)) AS rows_in_late_band,
  COUNT(*) AS rows_total,
  ROUND(SUM(IF(FORMAT_DATE("%Y-%m", DATE(moment,"Asia/Bishkek"))="2026-05", sum_kgs, 0)),2) AS sum_may_bishkek,
  ROUND(SUM(IF(FORMAT_DATE("%Y-%m", CAST(moment AS DATE))="2026-05", sum_kgs, 0)),2) AS sum_may_cast,
  ROUND(SUM(IF(FORMAT_DATE("%Y-%m", DATE(moment,"Asia/Bishkek"))="2026-07", sum_kgs, 0)),2) AS sum_jul_bishkek,
  ROUND(SUM(IF(FORMAT_DATE("%Y-%m", CAST(moment AS DATE))="2026-07", sum_kgs, 0)),2) AS sum_jul_cast
FROM u
GROUP BY source_name
'

echo "=== Условие 2 (ДО): marts.expenses — май-2026, эталон 10 232 903.20 ==="
bq query --use_legacy_sql=false --format=prettyjson '
SELECT
  ROUND(SUM(total_sum_kgs),2) AS total_kgs_may2026,
  COUNT(*) AS row_count
FROM `msklad-bi-prod.marts.expenses`
WHERE year_month = "2026-05"
'

echo "=== Условие 2 (ДО): core.fact_returns — май-2026, эталон 570 ==="
bq query --use_legacy_sql=false --format=prettyjson '
SELECT COUNT(*) AS row_count
FROM `msklad-bi-prod.core.fact_returns`
WHERE FORMAT_DATE("%Y-%m", return_date) = "2026-05"
'

echo "=== Условие 2 (ДО): core.fact_purchases — май-2026, эталон Δ=0 (печатаем COUNT/SUM для последующего сравнения) ==="
bq query --use_legacy_sql=false --format=prettyjson '
SELECT COUNT(*) AS row_count
FROM `msklad-bi-prod.core.fact_purchases`
WHERE FORMAT_DATE("%Y-%m", order_date) = "2026-05"
'

echo "=== date -u (end) ==="
date -u
echo "=== gcloud auth list (end) ==="
gcloud auth list
