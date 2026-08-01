#!/bin/bash
set -euo pipefail
OUT=reference/_scratch_PARITY-SALES-DISCRIMINATE_2026-08-01
echo "=== date -u (начало) ===" | tee "$OUT/step1_queries.log"
date -u | tee -a "$OUT/step1_queries.log"
echo "=== gcloud auth list (начало) ===" | tee -a "$OUT/step1_queries.log"
gcloud auth list | tee -a "$OUT/step1_queries.log"

echo "" | tee -a "$OUT/step1_queries.log"
echo "=== Запрос 1а: MIN/MAX(_loaded_at) + распределение по суткам ===" | tee -a "$OUT/step1_queries.log"

Q1A_MINMAX='SELECT MIN(_loaded_at) AS min_loaded_at, MAX(_loaded_at) AS max_loaded_at
FROM `msklad-bi-prod.core.fact_sales_profit`
WHERE transaction_date BETWEEN "2026-05-01" AND "2026-05-31"'
echo "--- SQL (minmax) ---" | tee -a "$OUT/step1_queries.log"
echo "$Q1A_MINMAX" | tee -a "$OUT/step1_queries.log"
bq query --use_legacy_sql=false --format=json "$Q1A_MINMAX" | tee "$OUT/step1a_minmax.json" | tee -a "$OUT/step1_queries.log"

Q1A_DIST='SELECT DATE(_loaded_at) AS loaded_date, COUNT(*) AS n_rows
FROM `msklad-bi-prod.core.fact_sales_profit`
WHERE transaction_date BETWEEN "2026-05-01" AND "2026-05-31"
GROUP BY loaded_date
ORDER BY loaded_date'
echo "--- SQL (distribution by loaded_date) ---" | tee -a "$OUT/step1_queries.log"
echo "$Q1A_DIST" | tee -a "$OUT/step1_queries.log"
bq query --use_legacy_sql=false --format=json "$Q1A_DIST" | tee "$OUT/step1a_dist.json" | tee -a "$OUT/step1_queries.log"

echo "" | tee -a "$OUT/step1_queries.log"
echo "=== Запрос 1б: сумма revenue_kgs по суткам transaction_date ===" | tee -a "$OUT/step1_queries.log"
Q1B='SELECT transaction_date, COUNT(*) AS n_rows, SUM(revenue_kgs) AS sum_revenue_kgs
FROM `msklad-bi-prod.core.fact_sales_profit`
WHERE transaction_date BETWEEN "2026-05-01" AND "2026-05-31"
GROUP BY transaction_date
ORDER BY transaction_date'
echo "--- SQL ---" | tee -a "$OUT/step1_queries.log"
echo "$Q1B" | tee -a "$OUT/step1_queries.log"
bq query --use_legacy_sql=false --format=json "$Q1B" | tee "$OUT/step1b_by_date.json" | tee -a "$OUT/step1_queries.log"

echo "" | tee -a "$OUT/step1_queries.log"
echo "=== Запрос 1в: число строк и сумма revenue_kgs по entity_type ===" | tee -a "$OUT/step1_queries.log"
Q1C='SELECT entity_type, COUNT(*) AS n_rows, SUM(revenue_kgs) AS sum_revenue_kgs
FROM `msklad-bi-prod.core.fact_sales_profit`
WHERE transaction_date BETWEEN "2026-05-01" AND "2026-05-31"
GROUP BY entity_type
ORDER BY entity_type'
echo "--- SQL ---" | tee -a "$OUT/step1_queries.log"
echo "$Q1C" | tee -a "$OUT/step1_queries.log"
bq query --use_legacy_sql=false --format=json "$Q1C" | tee "$OUT/step1c_by_entity_type.json" | tee -a "$OUT/step1_queries.log"

echo "" | tee -a "$OUT/step1_queries.log"
echo "=== date -u (конец) ===" | tee -a "$OUT/step1_queries.log"
date -u | tee -a "$OUT/step1_queries.log"
echo "=== gcloud auth list (конец) ===" | tee -a "$OUT/step1_queries.log"
gcloud auth list | tee -a "$OUT/step1_queries.log"
echo "PATH: $OUT"
