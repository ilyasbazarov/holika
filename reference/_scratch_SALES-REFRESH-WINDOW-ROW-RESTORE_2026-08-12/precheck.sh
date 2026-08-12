#!/usr/bin/env bash
set -euo pipefail

PROJECT="msklad-bi-prod"
DATASET="core"
TARGET="${PROJECT}.${DATASET}.fact_sales_profit"
SNAP="${PROJECT}.${DATASET}.fact_sales_profit_snap_20260811_163306"
ID1="786f54b87f1e81ecf04efead3ab59250"
ID2="8e05d4b486a48d5b018df201217eb7f3"

echo "=== date -u (start) ==="
date -u

echo "=== gcloud auth list (start) ==="
gcloud auth list

echo "=== 1) оба идентификатора отсутствуют в target — ожидание 0 ==="
bq query --project_id="${PROJECT}" --use_legacy_sql=false --format=prettyjson "
SELECT transaction_id, COUNT(*) AS n
FROM \`${TARGET}\`
WHERE transaction_id IN ('${ID1}', '${ID2}')
GROUP BY transaction_id
"

echo "=== 2) оба идентификатора присутствуют в снимке ровно по одному разу — ожидание 1 и 1 ==="
bq query --project_id="${PROJECT}" --use_legacy_sql=false --format=prettyjson "
SELECT transaction_id, COUNT(*) AS n
FROM \`${SNAP}\`
WHERE transaction_id IN ('${ID1}', '${ID2}')
GROUP BY transaction_id
"

echo "=== 3a) схема снимка — полный список имя+тип ==="
bq query --project_id="${PROJECT}" --use_legacy_sql=false --format=prettyjson "
SELECT column_name, data_type, ordinal_position
FROM \`${PROJECT}.${DATASET}\`.INFORMATION_SCHEMA.COLUMNS
WHERE table_name = 'fact_sales_profit_snap_20260811_163306'
ORDER BY ordinal_position
"

echo "=== 3b) схема цели — полный список имя+тип ==="
bq query --project_id="${PROJECT}" --use_legacy_sql=false --format=prettyjson "
SELECT column_name, data_type, ordinal_position
FROM \`${PROJECT}.${DATASET}\`.INFORMATION_SCHEMA.COLUMNS
WHERE table_name = 'fact_sales_profit'
ORDER BY ordinal_position
"

echo "=== 4) общее число строк target ДО вставки (нужно приёмке) ==="
bq query --project_id="${PROJECT}" --use_legacy_sql=false --format=prettyjson "
SELECT COUNT(*) AS row_count_before
FROM \`${TARGET}\`
"

echo "=== date -u (end) ==="
date -u

echo "=== gcloud auth list (end) ==="
gcloud auth list
