#!/bin/bash
# DQ-GATE-DEPLOY-ADJ · шаг 1 (класс A, read-only)
# Замер распределения ratio = daily_rev / MA7(T-8..T-2) по дням недели.
# Формула воспроизводит reference/code/cf-dq/main.py:45-57 (check_drift):
#   ma7 = AVG(daily_rev) по ФАКТИЧЕСКИ присутствующим суткам окна [d-7, d)
#   ratio = rev(d) / ma7
# Отличие от кода, названное явно: rev(d) берётся из CORE_FACT, а не из STAGING
# (staging эфемерен, TTL 14 суток) — тот же предел, что у dq_source_capture_2026-08-02.md §4,
# где допущение проверено фактом на двух реально сработавших субботах.
# ЯВНЫЙ -n: bq query без него молча обрезает до 100 строк (PARITY-STOCK-INTRANSIT, BQ-QUERY-MAX-ROWS).
set -uo pipefail
SCRATCH="reference/_scratch_DQ-GATE-DEPLOY-ADJ_2026-08-04"
PROJ="msklad-bi-prod"

echo "=== date -u (start) ==="; date -u
echo "=== gcloud auth list (start) ==="; gcloud auth list

CORE="\`msklad-bi-prod.core.fact_sales_profit\`"

read -r -d '' BASE <<SQL
WITH daily AS (
  SELECT transaction_date AS d, SUM(revenue_kgs) AS rev
  FROM ${CORE}
  GROUP BY 1
),
calc AS (
  SELECT
    a.d AS d,
    EXTRACT(DAYOFWEEK FROM a.d) AS dow,
    a.rev AS rev,
    (SELECT AVG(b.rev) FROM daily b WHERE b.d >= DATE_SUB(a.d, INTERVAL 7 DAY) AND b.d < a.d) AS ma7,
    (SELECT COUNT(*) FROM daily b WHERE b.d >= DATE_SUB(a.d, INTERVAL 7 DAY) AND b.d < a.d) AS win_days
  FROM daily a
)
SQL

echo
echo "=== 0. границы данных и независимый COUNT(*) ==="
bq query --project_id=$PROJ --use_legacy_sql=false --format=csv -n 100 \
"SELECT MIN(transaction_date) AS min_d, MAX(transaction_date) AS max_d,
        COUNT(DISTINCT transaction_date) AS n_days, COUNT(*) AS n_rows
 FROM ${CORE}" 2>"$SCRATCH/step1_q0.err" | tee "$SCRATCH/step1_q0_bounds.csv"

echo
echo "=== 1. ВСЕ выходные сутки (dow 1=вс, 7=сб), по возрастанию ratio ==="
bq query --project_id=$PROJ --use_legacy_sql=false --format=csv -n 5000 \
"${BASE}
 SELECT CAST(d AS STRING) AS day, dow,
        ROUND(rev,2) AS rev, ROUND(ma7,2) AS ma7,
        ROUND(SAFE_DIVIDE(rev, ma7),4) AS ratio, win_days
 FROM calc WHERE dow IN (1,7) AND ma7 IS NOT NULL AND ma7 > 0
 ORDER BY ratio ASC" 2>"$SCRATCH/step1_q1.err" | tee "$SCRATCH/step1_q1_weekend_all.csv"

echo
echo "=== 2. Сводка по дню недели (1=вс … 7=сб) ==="
bq query --project_id=$PROJ --use_legacy_sql=false --format=csv -n 100 \
"${BASE}
 SELECT dow, COUNT(*) AS n,
        ROUND(MIN(SAFE_DIVIDE(rev,ma7)),4)  AS ratio_min,
        ROUND(APPROX_QUANTILES(SAFE_DIVIDE(rev,ma7),100)[OFFSET(10)],4) AS ratio_p10,
        ROUND(APPROX_QUANTILES(SAFE_DIVIDE(rev,ma7),100)[OFFSET(50)],4) AS ratio_med,
        ROUND(MAX(SAFE_DIVIDE(rev,ma7)),4)  AS ratio_max,
        COUNTIF(SAFE_DIVIDE(rev,ma7) < 0.03) AS below_003,
        COUNTIF(SAFE_DIVIDE(rev,ma7) < 0.10) AS below_010,
        COUNTIF(SAFE_DIVIDE(rev,ma7) < 0.20) AS below_020
 FROM calc WHERE ma7 IS NOT NULL AND ma7 > 0
 GROUP BY dow ORDER BY dow" 2>"$SCRATCH/step1_q2.err" | tee "$SCRATCH/step1_q2_by_dow.csv"

echo
echo "=== 3. Сутки БЕЗ строк вовсе (в daily их нет — дыры календаря), последние 120 суток ==="
bq query --project_id=$PROJ --use_legacy_sql=false --format=csv -n 500 \
"WITH daily AS (SELECT transaction_date AS d FROM ${CORE} GROUP BY 1),
      cal AS (SELECT d FROM UNNEST(GENERATE_DATE_ARRAY(DATE '2026-04-06', DATE '2026-08-04')) AS d)
 SELECT CAST(cal.d AS STRING) AS missing_day, EXTRACT(DAYOFWEEK FROM cal.d) AS dow
 FROM cal LEFT JOIN daily ON daily.d = cal.d
 WHERE daily.d IS NULL ORDER BY cal.d" 2>"$SCRATCH/step1_q3.err" | tee "$SCRATCH/step1_q3_missing_days.csv"

echo
echo "=== stderr (непустой = смотреть) ==="
for f in "$SCRATCH"/step1_q*.err; do echo "--- $f"; cat "$f"; done

echo
echo "=== gcloud auth list (end) ==="; gcloud auth list
echo "=== date -u (end) ==="; date -u
echo "=== SCRATCH: $SCRATCH ==="
