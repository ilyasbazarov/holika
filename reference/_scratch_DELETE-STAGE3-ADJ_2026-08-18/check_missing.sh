#!/bin/bash
# Архитекторская проверка (класс A, read-only): отсутствуют ли удалённые строки в ядре СЕЙЧАС.
set -u
echo "=== UTC (старт) ==="; date -u
echo "=== gcloud auth list (старт) ==="; gcloud auth list 2>&1 | head -5

echo; echo "--- 1. Две удалённые строки пары маркетплейса присутствуют в ядре? ---"
bq query --use_legacy_sql=false --format=prettyjson --max_rows=50 '
SELECT transaction_id, transaction_date, agent_id, revenue_kgs, _loaded_at
FROM `msklad-bi-prod.core.fact_sales_profit`
WHERE transaction_id IN ("786f54b87f1e81ecf04efead3ab59250","8e05d4b486a48d5b018df201217eb7f3")
'

echo; echo "--- 2. Есть ли в ядре ЛЮБЫЕ строки этого контрагента за 2026-05-12 ---"
bq query --use_legacy_sql=false --format=prettyjson --max_rows=50 '
SELECT COUNT(*) AS rows_cnt, ROUND(SUM(revenue_kgs),2) AS sum_kgs
FROM `msklad-bi-prod.core.fact_sales_profit`
WHERE transaction_date = DATE "2026-05-12"
  AND agent_id = "31d135bc-4df8-11f1-0a80-1c8a0053c5b4"
'

echo; echo "--- 3. Итог мая в ядре сейчас (для оценки материальности) ---"
bq query --use_legacy_sql=false --format=prettyjson --max_rows=10 '
SELECT COUNT(*) AS rows_cnt, ROUND(SUM(revenue_kgs),2) AS revenue_may
FROM `msklad-bi-prod.core.fact_sales_profit`
WHERE transaction_date BETWEEN DATE "2026-05-01" AND DATE "2026-05-31"
'

echo; echo "=== UTC (конец) ==="; date -u
echo "=== gcloud auth list (конец) ==="; gcloud auth list 2>&1 | head -5
