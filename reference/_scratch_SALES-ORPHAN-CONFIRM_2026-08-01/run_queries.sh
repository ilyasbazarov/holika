#!/bin/bash
set -euo pipefail

echo "=== UTC-якорь (начало) ==="
date -u

echo "=== личность вызывающего (начало) ==="
gcloud auth list

echo
echo "=== Запрос 1: строки-сироты (не тронуты прогоном 2026-07-19) ==="
bq query --use_legacy_sql=false --project_id=msklad-bi-prod --format=pretty "
SELECT transaction_date, _loaded_at, transaction_id, product_id, revenue_kgs
FROM \`msklad-bi-prod.core.fact_sales_profit\`
WHERE transaction_date BETWEEN '2026-05-01' AND '2026-05-31'
  AND DATE(_loaded_at) < '2026-07-19'
ORDER BY transaction_date, _loaded_at
"

echo
echo "=== Запрос 2: замороженная дата — разрез по суткам 26/31 мая после прогона 2026-07-19 ==="
bq query --use_legacy_sql=false --project_id=msklad-bi-prod --format=pretty "
SELECT transaction_date, COUNT(*) AS n_rows, SUM(revenue_kgs) AS s
FROM \`msklad-bi-prod.core.fact_sales_profit\`
WHERE transaction_date IN ('2026-05-26','2026-05-31')
  AND DATE(_loaded_at) >= '2026-07-19'
GROUP BY transaction_date
"

echo
echo "=== личность вызывающего (конец) ==="
gcloud auth list

echo "=== UTC-якорь (конец) ==="
date -u
