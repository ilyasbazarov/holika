#!/usr/bin/env bash
set -u
P=msklad-bi-prod
echo "=== START $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
gcloud auth list 2>&1 | head -4
q() { echo; echo "--- $1 ---"; bq query --project_id=$P --use_legacy_sql=false --format=prettyjson -n 300 "$2" 2>&1; }

q "O1 заполненность document_owner_employee_id по месяцам, вся история" "
SELECT FORMAT_DATE('%Y-%m', transaction_date) AS ym,
       COUNT(*) AS total_rows,
       COUNTIF(document_owner_employee_id IS NOT NULL) AS filled,
       ROUND(100*SAFE_DIVIDE(COUNTIF(document_owner_employee_id IS NOT NULL),COUNT(*)),1) AS filled_pct,
       ROUND(SUM(revenue_kgs),2) AS revenue_kgs,
       ROUND(SUM(IF(document_owner_employee_id IS NULL, revenue_kgs, 0)),2) AS revenue_without_owner
FROM \`$P.core.fact_sales_profit\`
GROUP BY ym ORDER BY ym"

q "O2 владельцы документов, которых нет в dim_employees" "
SELECT COUNT(DISTINCT f.document_owner_employee_id) AS orphan_owner_ids,
       ROUND(SUM(f.revenue_kgs),2) AS revenue_kgs
FROM \`$P.core.fact_sales_profit\` f
LEFT JOIN \`$P.core.dim_employees\` e ON f.document_owner_employee_id = e.employee_id
WHERE f.document_owner_employee_id IS NOT NULL AND e.employee_id IS NULL"

q "O3 май-2026: разрез по обеим атрибуциям" "
SELECT
  ROUND(SUM(IF(f.document_owner_employee_id IS NULL, f.revenue_kgs, 0)),2) AS may_revenue_no_doc_owner,
  ROUND(SUM(f.revenue_kgs),2) AS may_revenue_total
FROM \`$P.core.fact_sales_profit\` f
WHERE f.transaction_date BETWEEN '2026-05-01' AND '2026-05-31'"

echo
gcloud auth list 2>&1 | head -4
echo "=== END $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
