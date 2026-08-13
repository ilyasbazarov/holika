#!/usr/bin/env bash
set -u
P=msklad-bi-prod
echo "=== START $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
gcloud auth list 2>&1 | head -4
q() { echo; echo "--- $1 ---"; bq query --project_id=$P --use_legacy_sql=false --format=prettyjson -n 100 "$2" 2>&1; }

q "T1 Sun Spray в ЯДРЕ на 2026-08-12 06:00 UTC (до деплоя SALES-REFRESH-WINDOW)" "
SELECT ROUND(SUM(revenue_kgs),2) AS revenue_kgs, COUNT(*) AS n_rows
FROM \`$P.core.fact_sales_profit\` FOR SYSTEM_TIME AS OF TIMESTAMP '2026-08-12 06:00:00 UTC'
WHERE product_id = 'da7c9a06-6c8d-11f1-0a80-1be70017b13b'
  AND transaction_date BETWEEN '2026-07-01' AND '2026-07-31'"

q "T2 Sun Spray в ЯДРЕ сейчас" "
SELECT ROUND(SUM(revenue_kgs),2) AS revenue_kgs, COUNT(*) AS n_rows
FROM \`$P.core.fact_sales_profit\`
WHERE product_id = 'da7c9a06-6c8d-11f1-0a80-1be70017b13b'
  AND transaction_date BETWEEN '2026-07-01' AND '2026-07-31'"

q "T3 Турдалиева по владельцу документа на 2026-08-12 06:00 UTC" "
SELECT ROUND(SUM(f.revenue_kgs),2) AS revenue_kgs
FROM \`$P.core.fact_sales_profit\` FOR SYSTEM_TIME AS OF TIMESTAMP '2026-08-12 06:00:00 UTC' f
LEFT JOIN \`$P.core.dim_employees\` e ON f.document_owner_employee_id = e.employee_id
WHERE f.transaction_date BETWEEN '2026-07-01' AND '2026-07-31'
  AND e.full_name = 'Турдалиева А. М.'"

q "T4 когда витрина sales_overview последний раз пересобиралась" "
SELECT MAX(_mart_refreshed_at) AS mart_refreshed_at FROM \`$P.marts.sales_overview\`"

echo
gcloud auth list 2>&1 | head -4
echo "=== END $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
