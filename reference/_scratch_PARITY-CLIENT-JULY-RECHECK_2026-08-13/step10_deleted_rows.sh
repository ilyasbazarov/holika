#!/usr/bin/env bash
set -u
P=msklad-bi-prod
echo "=== START $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
gcloud auth list 2>&1 | head -4
q() { echo; echo "--- $1 ---"; bq query --project_id=$P --use_legacy_sql=false --format=prettyjson -n 100 "$2" 2>&1; }

q "X1 четыре строки, исчезнувшие по этому товару" "
SELECT s.transaction_id, s.transaction_date, s.sell_quantity, ROUND(s.revenue_kgs,2) AS revenue_kgs,
       s.sales_channel_name, s.agent_id
FROM \`$P.core.fact_sales_profit_snap_20260811_163306\` s
LEFT JOIN \`$P.core.fact_sales_profit\` c USING (transaction_id)
WHERE s.product_id='da7c9a06-6c8d-11f1-0a80-1be70017b13b'
  AND s.transaction_date BETWEEN '2026-07-01' AND '2026-07-31'
  AND c.transaction_id IS NULL
ORDER BY s.revenue_kgs DESC"

q "X2 сколько всего строк июля исчезло из ядра против снимка и на какую сумму" "
SELECT COUNT(*) AS lost_rows, ROUND(SUM(s.revenue_kgs),2) AS lost_revenue_kgs
FROM \`$P.core.fact_sales_profit_snap_20260811_163306\` s
LEFT JOIN \`$P.core.fact_sales_profit\` c USING (transaction_id)
WHERE s.transaction_date BETWEEN '2026-07-01' AND '2026-07-31'
  AND c.transaction_id IS NULL"

q "X3 Турдалиева за июль по снимку (по владельцу документа) — что видел клиент" "
SELECT ROUND(SUM(s.revenue_kgs),2) AS revenue_kgs
FROM \`$P.core.fact_sales_profit_snap_20260811_163306\` s
LEFT JOIN \`$P.core.dim_employees\` e ON s.document_owner_employee_id = e.employee_id
WHERE s.transaction_date BETWEEN '2026-07-01' AND '2026-07-31'
  AND e.full_name = 'Турдалиева А. М.'"

echo
gcloud auth list 2>&1 | head -4
echo "=== END $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
