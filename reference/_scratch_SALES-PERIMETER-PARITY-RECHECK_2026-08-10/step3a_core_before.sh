#!/usr/bin/env bash
# Снимок core.fact_sales_profit ДО досева (провенанс/точка отката), read-only.
set -euo pipefail
OUT="$(dirname "$0")"
echo "=== date -u (начало) ==="
date -u
echo "=== gcloud auth list (начало) ==="
gcloud auth list

bq query --use_legacy_sql=false --format=prettyjson "
SELECT
  COUNT(*) AS n_rows,
  ROUND(SUM(revenue_kgs),2) AS revenue_kgs
FROM \`msklad-bi-prod.core.fact_sales_profit\`
WHERE transaction_date >= DATE('2026-05-01') AND transaction_date < DATE('2026-06-01')
" > "$OUT/step3a_core_before_may.json"
cat "$OUT/step3a_core_before_may.json"

bq query --use_legacy_sql=false --format=prettyjson "
SELECT COUNT(*) AS n_rows, ROUND(SUM(revenue_kgs),2) AS revenue_kgs
FROM \`msklad-bi-prod.core.fact_sales_profit\`
" > "$OUT/step3a_core_before_alltime.json"
cat "$OUT/step3a_core_before_alltime.json"

echo "=== date -u (конец) ==="
date -u
echo "=== gcloud auth list (конец) ==="
gcloud auth list
