#!/usr/bin/env bash
# FACTS-FLOW-RESTORE-ADJ · шаг 1 — арифметика гейта: что он посчитает сегодня и в ближайшие дни.
#
# Три вопроса шага, все снимаются read-only и без обращения к МойСкладу:
#   1. Что лежит в staging по суткам — упала ли выручка в ИСТОЧНИКЕ или недоезжает загрузка.
#   2. Что лежит в ядре по суткам — какие сутки войдут в окно MA7 в ближайшие дни.
#   3. Когда окно MA7 (T-8…T-2) перестанет пересекаться с непустой историей ядра: при `ma7 == 0`
#      чек проходит без проверки ratio (`reference/code/cf-dq/main.py:54-55`), то есть блокировка
#      снимается сама — вопрос в дате.
#
# Класс A: только read-only `bq query`, секретов нет, живых вызовов к МойСкладу нет.
set -uo pipefail
PROJECT=msklad-bi-prod

echo "=== UTC anchor (start) ==="
date -u
echo "=== identity (start) ==="
gcloud auth list

echo
echo "=== step1a: staging по суткам (то, что видит drift_check как target_rev) ==="
bq query --project_id="$PROJECT" --use_legacy_sql=false --format=prettyjson --max_rows=100 '
SELECT
  DATE(PARSE_TIMESTAMP("%Y-%m-%d %H:%M:%E3S", transaction_date_raw), "Asia/Bishkek") AS d_bishkek,
  COUNT(*)                        AS n_rows,
  ROUND(SUM(revenue_kgs), 2)      AS revenue_kgs
FROM `msklad-bi-prod.stg_msklad.fact_sales_staging`
GROUP BY d_bishkek
ORDER BY d_bishkek
'

echo
echo "=== step1b: ядро по суткам за последние 20 дней (то, из чего считается ma7) ==="
bq query --project_id="$PROJECT" --use_legacy_sql=false --format=prettyjson --max_rows=100 '
SELECT
  transaction_date,
  COUNT(*)                   AS n_rows,
  ROUND(SUM(revenue_kgs), 2) AS revenue_kgs
FROM `msklad-bi-prod.core.fact_sales_profit`
WHERE transaction_date >= DATE_SUB(CURRENT_DATE("Asia/Bishkek"), INTERVAL 20 DAY)
GROUP BY transaction_date
ORDER BY transaction_date
'

echo
echo "=== step1c: воспроизведение ma7 гейта на СЕГОДНЯ (окно T-8..T-2, дословно main.py:45-52) ==="
bq query --project_id="$PROJECT" --use_legacy_sql=false --format=prettyjson --max_rows=10 '
SELECT
  COUNT(*)                                  AS n_days_in_window,
  ROUND(COALESCE(AVG(daily_rev), 0), 2)     AS ma7
FROM (
  SELECT transaction_date, SUM(revenue_kgs) AS daily_rev
  FROM `msklad-bi-prod.core.fact_sales_profit`
  WHERE transaction_date >= DATE_SUB(CURRENT_DATE("Asia/Bishkek"), INTERVAL 8 DAY)
    AND transaction_date  <  DATE_SUB(CURRENT_DATE("Asia/Bishkek"), INTERVAL 1 DAY)
  GROUP BY 1)
'

echo
echo "=== step1d: прогноз ma7 по датам будущих прогонов (та же формула со сдвигом опорной даты) ==="
bq query --project_id="$PROJECT" --use_legacy_sql=false --format=prettyjson --max_rows=100 '
WITH days AS (
  SELECT d AS run_date
  FROM UNNEST(GENERATE_DATE_ARRAY(
        CURRENT_DATE("Asia/Bishkek"),
        DATE_ADD(CURRENT_DATE("Asia/Bishkek"), INTERVAL 9 DAY))) AS d
),
core AS (
  SELECT transaction_date, SUM(revenue_kgs) AS daily_rev
  FROM `msklad-bi-prod.core.fact_sales_profit`
  GROUP BY 1
)
SELECT
  days.run_date,
  DATE_SUB(days.run_date, INTERVAL 8 DAY) AS window_from,
  DATE_SUB(days.run_date, INTERVAL 2 DAY) AS window_to_incl,
  COUNTIF(core.transaction_date IS NOT NULL)                       AS n_days_with_data,
  ROUND(COALESCE(AVG(core.daily_rev), 0), 2)                       AS ma7_projected
FROM days
LEFT JOIN core
  ON core.transaction_date >= DATE_SUB(days.run_date, INTERVAL 8 DAY)
 AND core.transaction_date  < DATE_SUB(days.run_date, INTERVAL 1 DAY)
GROUP BY days.run_date
ORDER BY days.run_date
'

echo
echo "=== identity (end) ==="
gcloud auth list
echo "=== UTC anchor (end) ==="
date -u
echo "SCRATCH_PATH=reference/_scratch_FACTS-FLOW-RESTORE-ADJ_2026-08-04"
