#!/usr/bin/env bash
# Read-back после MERGE: подтвердить прирост прямым запросом, не по отчёту команды.
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
" > "$OUT/step3e_core_after_may.json"
cat "$OUT/step3e_core_after_may.json"

echo "=== досеянные строки разрыва (2026-05-04, entity_type=commissionreportin_sale, два agent_id из шага 2) ==="
bq query --use_legacy_sql=false --format=prettyjson "
SELECT transaction_id, agent_id, entity_type, COUNT(*) AS n_rows, ROUND(SUM(revenue_kgs),2) AS revenue_kgs
FROM \`msklad-bi-prod.core.fact_sales_profit\`
WHERE transaction_date = DATE('2026-05-04')
  AND entity_type = 'commissionreportin_sale'
  AND agent_id IN ('3c080755-03ff-11f0-0a80-0c2c00104bbb','0276f431-2ff5-11ef-0a80-11d40019917f')
GROUP BY transaction_id, agent_id, entity_type
" > "$OUT/step3e_gap_docs_in_core.json"
cat "$OUT/step3e_gap_docs_in_core.json"

echo "=== date -u (конец) ==="
date -u
echo "=== gcloud auth list (конец) ==="
gcloud auth list
