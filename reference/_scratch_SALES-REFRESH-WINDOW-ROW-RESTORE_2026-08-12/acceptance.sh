#!/usr/bin/env bash
set -euo pipefail

PROJECT="msklad-bi-prod"
DATASET="core"
TARGET="${PROJECT}.${DATASET}.fact_sales_profit"
SNAP="${PROJECT}.${DATASET}.fact_sales_profit_snap_20260811_163306"
ID1="786f54b87f1e81ecf04efead3ab59250"
ID2="8e05d4b486a48d5b018df201217eb7f3"
ROW_COUNT_BEFORE=42986

echo "=== date -u (start) ==="
date -u

echo "=== gcloud auth list (start) ==="
gcloud auth list

echo "=== ПРИЁМКА 1: наличие, сумма revenue_kgs, рост числа строк ==="
echo "--- присутствие каждого id ровно один раз ---"
bq query --project_id="${PROJECT}" --use_legacy_sql=false --format=prettyjson "
SELECT transaction_id, COUNT(*) AS n, SUM(revenue_kgs) AS revenue_kgs
FROM \`${TARGET}\`
WHERE transaction_id IN ('${ID1}', '${ID2}')
GROUP BY transaction_id
"

echo "--- сумма revenue_kgs по обеим строкам вместе (ожидание 1980000.00) ---"
bq query --project_id="${PROJECT}" --use_legacy_sql=false --format=prettyjson "
SELECT SUM(revenue_kgs) AS revenue_kgs_sum
FROM \`${TARGET}\`
WHERE transaction_id IN ('${ID1}', '${ID2}')
"

echo "--- общее число строк target СЕЙЧАС (ожидание ${ROW_COUNT_BEFORE} + 2) ---"
bq query --project_id="${PROJECT}" --use_legacy_sql=false --format=prettyjson "
SELECT COUNT(*) AS row_count_after
FROM \`${TARGET}\`
"

echo "=== ПРИЁМКА 2 (ГЛАВНОЕ): разность SUM(revenue_kgs) за 2026-05-01..2026-05-31 снимок минус живая (ожидание ТОЧНО 1630239.81) ==="
bq query --project_id="${PROJECT}" --use_legacy_sql=false --format=prettyjson "
WITH snap_may AS (
  SELECT SUM(revenue_kgs) AS s
  FROM \`${SNAP}\`
  WHERE transaction_date BETWEEN '2026-05-01' AND '2026-05-31'
),
live_may AS (
  SELECT SUM(revenue_kgs) AS s
  FROM \`${TARGET}\`
  WHERE transaction_date BETWEEN '2026-05-01' AND '2026-05-31'
)
SELECT snap_may.s AS snap_sum, live_may.s AS live_sum, (snap_may.s - live_may.s) AS diff
FROM snap_may, live_may
"

echo "=== ПРИЁМКА 3: разность раскладывается на семь именованных идентификаторов сирот и ни на что ещё ==="
echo "--- строки, присутствующие в снимке за май, но отсутствующие в живой таблице (LEFT JOIN, COUNT(*)) ---"
bq query --project_id="${PROJECT}" --use_legacy_sql=false --format=prettyjson "
SELECT s.transaction_id, s.revenue_kgs, s.transaction_date
FROM \`${SNAP}\` s
LEFT JOIN \`${TARGET}\` l
  ON s.transaction_id = l.transaction_id
WHERE s.transaction_date BETWEEN '2026-05-01' AND '2026-05-31'
  AND l.transaction_id IS NULL
ORDER BY s.transaction_id
"

echo "--- COUNT(*) той же выборки (ожидание ровно 7) ---"
bq query --project_id="${PROJECT}" --use_legacy_sql=false --format=prettyjson "
SELECT COUNT(*) AS n_missing
FROM \`${SNAP}\` s
LEFT JOIN \`${TARGET}\` l
  ON s.transaction_id = l.transaction_id
WHERE s.transaction_date BETWEEN '2026-05-01' AND '2026-05-31'
  AND l.transaction_id IS NULL
"

echo "=== date -u (end) ==="
date -u

echo "=== gcloud auth list (end) ==="
gcloud auth list
