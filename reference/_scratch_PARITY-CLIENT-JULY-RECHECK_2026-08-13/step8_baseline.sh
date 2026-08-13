#!/usr/bin/env bash
set -u
P=msklad-bi-prod
echo "=== START $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
gcloud auth list 2>&1 | head -4
q() { echo; echo "--- $1 ---"; bq query --project_id=$P --use_legacy_sql=false --format=prettyjson -n 300 "$2" 2>&1; }

q "BL1 витрина: апрель-2026 по менеджеру (эталон неизменности истории)" "
SELECT COALESCE(manager_name,'(NULL)') AS manager_name, ROUND(SUM(revenue_kgs),2) AS revenue_kgs
FROM \`$P.marts.sales_overview\`
WHERE transaction_date BETWEEN '2026-04-01' AND '2026-04-30'
GROUP BY manager_name ORDER BY revenue_kgs DESC"

q "BL2 витрина: суммарная выручка июля и мая (инвариант — не меняется)" "
SELECT
  ROUND(SUM(IF(transaction_date BETWEEN '2026-07-01' AND '2026-07-31', revenue_kgs, 0)),2) AS july_total,
  ROUND(SUM(IF(transaction_date BETWEEN '2026-05-01' AND '2026-05-31', revenue_kgs, 0)),2) AS may_total,
  ROUND(SUM(IF(transaction_date BETWEEN '2026-04-01' AND '2026-04-30', revenue_kgs, 0)),2) AS april_total,
  ROUND(SUM(revenue_kgs),2) AS all_total
FROM \`$P.marts.sales_overview\`"

q "BL3 ожидаемый ПОСЛЕ правки разрез мая по владельцу документа" "
SELECT COALESCE(e.full_name,'Не указан') AS manager_name, ROUND(SUM(f.revenue_kgs),2) AS revenue_kgs
FROM \`$P.core.fact_sales_profit\` f
LEFT JOIN \`$P.core.dim_employees\` e ON f.document_owner_employee_id = e.employee_id
WHERE f.transaction_date BETWEEN '2026-05-01' AND '2026-05-31'
GROUP BY manager_name ORDER BY revenue_kgs DESC"

echo
gcloud auth list 2>&1 | head -4
echo "=== END $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
