#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

echo "=== UTC-якорь (начало) ==="
date -u
echo "=== личность вызывающего (начало) ==="
gcloud auth list

echo "=== bq query — текст дословно из reference/sales_july_k2k3_adj_2026-08-08.md §2.7 ==="
bq query --project_id=msklad-bi-prod --use_legacy_sql=false --format=prettyjson -n 1000 '
SELECT transaction_date, DATE(_loaded_at) AS loaded_date,
       COUNT(*) AS n_rows, SUM(revenue_kgs) AS sum_revenue_kgs
FROM `msklad-bi-prod.core.fact_sales_profit`
WHERE transaction_date IN ("2026-07-20","2026-07-21","2026-07-27","2026-07-29","2026-07-30")
  AND (sales_channel_name IS NULL OR sales_channel_name = "Оптовая торговля")
GROUP BY 1, 2 ORDER BY 1, 2
' | tee step1_result.json

echo "=== личность вызывающего (конец) ==="
gcloud auth list
echo "=== UTC-якорь (конец) ==="
date -u
