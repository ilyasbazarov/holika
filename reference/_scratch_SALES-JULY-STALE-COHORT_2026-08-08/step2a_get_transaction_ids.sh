#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

echo "=== UTC-якорь (начало) ==="
date -u
echo "=== личность вызывающего (начало) ==="
gcloud auth list

echo "=== read-only запрос transaction_id одиннадцати строк подслучая A ==="
echo "--- подслучай A, сутки 07-21 (стухшая когорта loaded_date=2026-07-22, 8 строк) ---"
bq query --project_id=msklad-bi-prod --use_legacy_sql=false --format=prettyjson -n 1000 '
SELECT transaction_id, transaction_date, DATE(_loaded_at) AS loaded_date, revenue_kgs
FROM `msklad-bi-prod.core.fact_sales_profit`
WHERE transaction_date = "2026-07-21"
  AND DATE(_loaded_at) = "2026-07-22"
  AND (sales_channel_name IS NULL OR sales_channel_name = "Оптовая торговля")
ORDER BY transaction_id
' | tee step2a_txids_0721.json

echo "--- подслучай A, сутки 07-30 (стухшая когорта loaded_date=2026-08-01, 3 строки) ---"
bq query --project_id=msklad-bi-prod --use_legacy_sql=false --format=prettyjson -n 1000 '
SELECT transaction_id, transaction_date, DATE(_loaded_at) AS loaded_date, revenue_kgs
FROM `msklad-bi-prod.core.fact_sales_profit`
WHERE transaction_date = "2026-07-30"
  AND DATE(_loaded_at) = "2026-08-01"
  AND (sales_channel_name IS NULL OR sales_channel_name = "Оптовая торговля")
ORDER BY transaction_id
' | tee step2a_txids_0730.json

echo "=== личность вызывающего (конец) ==="
gcloud auth list
echo "=== UTC-якорь (конец) ==="
date -u
