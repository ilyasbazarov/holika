#!/usr/bin/env bash
set -u
P=msklad-bi-prod
echo "=== START $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
gcloud auth list 2>&1 | head -4
q() { echo; echo "--- $1 ---"; bq query --project_id=$P --use_legacy_sql=false --format=prettyjson -n 300 "$2" 2>&1; }

q "N1 документ Эргешевой построчно (has_basis=true, 2026-07-01)" "
SELECT p.name AS product_name, r.quantity, ROUND(r.sum_kgs,2) AS sum_kgs, ROUND(r.cost_kgs,2) AS cost_kgs
FROM \`$P.core.fact_returns\` r
LEFT JOIN \`$P.core.dim_products\` p ON r.product_id = p.product_id
WHERE r.return_id = '0d9650b7-7549-11f1-0a80-19c400103fb5'
ORDER BY r.sum_kgs DESC"

q "N2 все возвраты по датам и признаку основания, вся история" "
SELECT return_date, has_basis, COUNT(DISTINCT return_id) AS n_docs,
       COUNT(*) AS n_pos, ROUND(SUM(sum_kgs),2) AS sum_kgs
FROM \`$P.core.fact_returns\`
GROUP BY return_date, has_basis ORDER BY return_date"

q "N3 продажи Эргешевой за июль (контрагент возврата)" "
SELECT c.name AS agent_name, ROUND(SUM(f.revenue_kgs),2) AS revenue_kgs, COUNT(*) AS n_rows
FROM \`$P.core.fact_sales_profit\` f
JOIN \`$P.core.dim_counterparties\` c ON f.agent_id = c.agent_id AND c.scd2_is_current = TRUE
WHERE f.transaction_date BETWEEN '2026-07-01' AND '2026-07-31'
  AND LOWER(c.name) LIKE '%эргешева%'
GROUP BY agent_name"

echo
gcloud auth list 2>&1 | head -4
echo "=== END $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
