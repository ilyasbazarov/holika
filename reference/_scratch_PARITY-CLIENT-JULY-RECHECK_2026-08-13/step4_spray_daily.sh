#!/usr/bin/env bash
set -u
P=msklad-bi-prod
echo "=== START $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
gcloud auth list 2>&1 | head -4
q() { echo; echo "--- $1 ---"; bq query --project_id=$P --use_legacy_sql=false --format=prettyjson -n 300 "$2" 2>&1; }

q "D1 Sun Spray по дням, 25 июня - 5 августа (витрина)" "
SELECT transaction_date, ROUND(SUM(revenue_kgs),2) AS revenue_kgs
FROM \`$P.marts.sales_overview\`
WHERE product_id = 'da7c9a06-6c8d-11f1-0a80-1be70017b13b'
  AND transaction_date BETWEEN '2026-06-25' AND '2026-08-05'
GROUP BY transaction_date ORDER BY transaction_date"

q "D2 кандидаты периода: суммы при сдвигах границ" "
SELECT
  ROUND(SUM(IF(transaction_date BETWEEN '2026-07-01' AND '2026-07-31', revenue_kgs, 0)),2) AS jul01_jul31,
  ROUND(SUM(IF(transaction_date BETWEEN '2026-06-30' AND '2026-07-31', revenue_kgs, 0)),2) AS jun30_jul31,
  ROUND(SUM(IF(transaction_date BETWEEN '2026-07-01' AND '2026-08-01', revenue_kgs, 0)),2) AS jul01_aug01,
  ROUND(SUM(IF(transaction_date BETWEEN '2026-06-30' AND '2026-08-01', revenue_kgs, 0)),2) AS jun30_aug01
FROM \`$P.marts.sales_overview\`
WHERE product_id = 'da7c9a06-6c8d-11f1-0a80-1be70017b13b'"

q "D3 июльские возвраты: агрегат по документу (return_id)" "
SELECT r.return_id, r.has_basis, MIN(r.return_date) AS d, COUNT(*) AS n_pos,
       ROUND(SUM(r.sum_kgs),2) AS doc_sum_kgs, ANY_VALUE(c.name) AS agent_name
FROM \`$P.core.fact_returns\` r
LEFT JOIN \`$P.core.dim_counterparties\` c ON r.agent_id = c.agent_id AND c.scd2_is_current = TRUE
WHERE r.return_date BETWEEN '2026-07-01' AND '2026-07-31'
GROUP BY r.return_id, r.has_basis ORDER BY doc_sum_kgs DESC"

echo
gcloud auth list 2>&1 | head -4
echo "=== END $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
