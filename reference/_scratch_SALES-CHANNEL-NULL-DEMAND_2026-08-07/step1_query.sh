#!/usr/bin/env bash
set -euo pipefail

PROJECT="msklad-bi-prod"
SCRATCH="reference/_scratch_SALES-CHANNEL-NULL-DEMAND_2026-08-07"

echo "=== UTC anchor (start) ==="
date -u

echo "=== identity (start) ==="
gcloud auth list --format="table(account,status)"

echo
echo "=== 0. независимый COUNT(*) NULL-строк за июль ==="
bq query --project_id="$PROJECT" --use_legacy_sql=false --format=prettyjson --max_rows=10 "
SELECT COUNT(*) AS n_rows, ROUND(SUM(revenue_kgs), 2) AS sum_revenue_kgs
FROM \`$PROJECT.core.fact_sales_profit\`
WHERE transaction_date BETWEEN '2026-07-01' AND '2026-07-31'
  AND sales_channel_name IS NULL
" | tee "$SCRATCH/00_count.json"

echo
echo "=== 1. Сами строки (не агрегат) — лимит заведомо больше ожидаемых 40 ==="
bq query --project_id="$PROJECT" --use_legacy_sql=false --format=prettyjson --max_rows=1000 "
SELECT
  transaction_id,
  transaction_date,
  agent_id,
  product_id,
  revenue_kgs,
  sales_channel_id,
  sales_channel_name,
  _loaded_at
FROM \`$PROJECT.core.fact_sales_profit\`
WHERE transaction_date BETWEEN '2026-07-01' AND '2026-07-31'
  AND sales_channel_name IS NULL
ORDER BY transaction_date, transaction_id
" | tee "$SCRATCH/01_rows.json"

echo
echo "=== 2. Распределение по суткам ==="
bq query --project_id="$PROJECT" --use_legacy_sql=false --format=prettyjson --max_rows=100 "
SELECT
  transaction_date,
  COUNT(*) AS n_rows,
  ROUND(SUM(revenue_kgs), 2) AS sum_revenue_kgs
FROM \`$PROJECT.core.fact_sales_profit\`
WHERE transaction_date BETWEEN '2026-07-01' AND '2026-07-31'
  AND sales_channel_name IS NULL
GROUP BY transaction_date
ORDER BY transaction_date
" | tee "$SCRATCH/02_by_date.json"

echo
echo "=== 3. Распределение по контрагентам (agent_id) ==="
bq query --project_id="$PROJECT" --use_legacy_sql=false --format=prettyjson --max_rows=100 "
SELECT
  agent_id,
  COUNT(*) AS n_rows,
  ROUND(SUM(revenue_kgs), 2) AS sum_revenue_kgs
FROM \`$PROJECT.core.fact_sales_profit\`
WHERE transaction_date BETWEEN '2026-07-01' AND '2026-07-31'
  AND sales_channel_name IS NULL
GROUP BY agent_id
ORDER BY sum_revenue_kgs DESC
" | tee "$SCRATCH/03_by_agent.json"

echo
echo "=== 4. Проверка ветки entity/demand: метки периметра «Розница»/«Комиссия» обязаны отсутствовать ==="
bq query --project_id="$PROJECT" --use_legacy_sql=false --format=prettyjson --max_rows=100 "
SELECT
  sales_channel_name,
  COUNT(*) AS n_rows
FROM \`$PROJECT.core.fact_sales_profit\`
WHERE transaction_date BETWEEN '2026-07-01' AND '2026-07-31'
  AND sales_channel_name IS NULL
GROUP BY sales_channel_name
" | tee "$SCRATCH/04_perimeter_labels.json"

echo
echo "=== 5. sales_channel_id vs sales_channel_name — ключевой различитель точки потери ==="
bq query --project_id="$PROJECT" --use_legacy_sql=false --format=prettyjson --max_rows=100 "
SELECT
  CASE WHEN sales_channel_id IS NULL THEN 'id_NULL' ELSE 'id_NOT_NULL' END AS id_state,
  COUNT(*) AS n_rows
FROM \`$PROJECT.core.fact_sales_profit\`
WHERE transaction_date BETWEEN '2026-07-01' AND '2026-07-31'
  AND sales_channel_name IS NULL
GROUP BY id_state
" | tee "$SCRATCH/05_id_vs_name.json"

echo
echo "=== identity (end) ==="
gcloud auth list --format="table(account,status)"

echo "=== UTC anchor (end) ==="
date -u

echo
echo "SCRATCH_DIR: $SCRATCH"
