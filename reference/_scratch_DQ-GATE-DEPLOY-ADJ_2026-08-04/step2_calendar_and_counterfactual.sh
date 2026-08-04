#!/bin/bash
# DQ-GATE-DEPLOY-ADJ · шаг 2 (класс A, read-only)
# Шаг 1 считал только сутки, ПРИСУТСТВУЮЩИЕ в core (в них есть строки). Сутки БЕЗ единого
# документа в `daily` не попадают вовсе — а именно они дают target_rev=0 и ratio=0, то есть
# проваливают чек при ЛЮБОМ положительном пороге. Шаг 2 достраивает календарь и считает
# контрфактические счётчики: сколько суток провалило бы чек при текущих порогах и при
# кандидатах ниже, с разделением «ноль документов» / «мало документов».
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
cal AS (
  SELECT d FROM UNNEST(GENERATE_DATE_ARRAY(DATE '2025-05-08', DATE '2026-08-01')) AS d
),
calc AS (
  SELECT
    cal.d AS d,
    EXTRACT(DAYOFWEEK FROM cal.d) AS dow,
    COALESCE(daily.rev, 0) AS rev,
    (daily.d IS NULL) AS no_rows,
    (SELECT AVG(b.rev) FROM daily b WHERE b.d >= DATE_SUB(cal.d, INTERVAL 7 DAY) AND b.d < cal.d) AS ma7
  FROM cal LEFT JOIN daily ON daily.d = cal.d
),
v AS (
  SELECT d, dow, rev, no_rows, ma7,
         SAFE_DIVIDE(rev, ma7) AS ratio,
         IF(dow IN (1,7), 0.03, 0.10) AS thr,
         IF(dow IN (1,7), 'weekend', 'weekday') AS kind
  FROM calc WHERE ma7 IS NOT NULL AND ma7 > 0
)
SQL

echo
echo "=== 1. Эра действующей ревизии: все календарные сутки 2026-06-18…2026-08-01 ==="
bq query --project_id=$PROJ --use_legacy_sql=false --format=csv -n 200 \
"${BASE}
 SELECT CAST(d AS STRING) AS day, dow, kind, ROUND(rev,2) AS rev, ROUND(ma7,2) AS ma7,
        ROUND(ratio,4) AS ratio, thr, no_rows,
        IF(ratio >= thr, 'PASS', 'FAIL') AS verdict
 FROM v WHERE d >= DATE '2026-06-18' ORDER BY d" 2>"$SCRATCH/step2_q1.err" | tee "$SCRATCH/step2_q1_current_era.csv"

echo
echo "=== 2. Контрфакт по всей истории (2025-05-08…2026-08-01): сколько провалов и какого рода ==="
bq query --project_id=$PROJ --use_legacy_sql=false --format=csv -n 100 \
"${BASE}
 SELECT kind, COUNT(*) AS days,
        COUNTIF(no_rows) AS days_zero_docs,
        COUNTIF(ratio < thr) AS fail_current,
        COUNTIF(ratio < thr AND no_rows) AS fail_zero_docs,
        COUNTIF(ratio < thr AND NOT no_rows) AS fail_low_but_nonzero,
        COUNTIF(ratio < 0.010) AS fail_at_0010,
        COUNTIF(ratio < 0.005) AS fail_at_0005,
        COUNTIF(ratio < 0.001) AS fail_at_0001,
        COUNTIF(ratio = 0)     AS fail_at_any_positive
 FROM v GROUP BY kind ORDER BY kind" 2>"$SCRATCH/step2_q2.err" | tee "$SCRATCH/step2_q2_counterfactual.csv"

echo
echo "=== 3. То же, только эра действующей ревизии (2026-06-18…2026-08-01) ==="
bq query --project_id=$PROJ --use_legacy_sql=false --format=csv -n 100 \
"${BASE}
 SELECT kind, COUNT(*) AS days,
        COUNTIF(no_rows) AS days_zero_docs,
        COUNTIF(ratio < thr) AS fail_current,
        COUNTIF(ratio < thr AND no_rows) AS fail_zero_docs,
        COUNTIF(ratio < thr AND NOT no_rows) AS fail_low_but_nonzero,
        COUNTIF(ratio < 0.010) AS fail_at_0010,
        COUNTIF(ratio = 0)     AS fail_at_any_positive
 FROM v WHERE d >= DATE '2026-06-18' GROUP BY kind ORDER BY kind" 2>"$SCRATCH/step2_q3.err" | tee "$SCRATCH/step2_q3_current_era_counts.csv"

echo
echo "=== 4. Провалы выходных с rev>0: полный список, чтобы видеть, есть ли разделяющее число ==="
bq query --project_id=$PROJ --use_legacy_sql=false --format=csv -n 500 \
"${BASE}
 SELECT CAST(d AS STRING) AS day, dow, ROUND(rev,2) AS rev, ROUND(ma7,2) AS ma7,
        ROUND(ratio,5) AS ratio
 FROM v WHERE kind='weekend' AND ratio < 0.03 ORDER BY ratio" 2>"$SCRATCH/step2_q4.err" | tee "$SCRATCH/step2_q4_weekend_fails.csv"

echo
echo "=== stderr (непустой = смотреть) ==="
for f in "$SCRATCH"/step2_q*.err; do echo "--- $f"; cat "$f"; done

echo
echo "=== gcloud auth list (end) ==="; gcloud auth list
echo "=== date -u (end) ==="; date -u
echo "=== SCRATCH: $SCRATCH ==="
