#!/usr/bin/env bash
set -u
P=msklad-bi-prod
echo "=== START $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
gcloud auth list 2>&1 | head -4
q() { echo; echo "--- $1 ---"; bq query --project_id=$P --use_legacy_sql=false --format=prettyjson -n 300 "$2" 2>&1; }

q "S1 все product_id с именем Sun Spray — ядро, июль" "
SELECT f.product_id, p.name AS product_name, p.entity_type AS dim_entity_type,
       COUNT(*) AS n_rows, ROUND(SUM(f.revenue_kgs),2) AS revenue_kgs
FROM \`$P.core.fact_sales_profit\` f
JOIN \`$P.core.dim_products\` p ON f.product_id = p.product_id
WHERE f.transaction_date BETWEEN '2026-07-01' AND '2026-07-31'
  AND LOWER(p.name) LIKE '%sun spray%'
GROUP BY f.product_id, product_name, dim_entity_type ORDER BY revenue_kgs DESC"

q "S2 та же выборка из ВИТРИНЫ marts.sales_overview" "
SELECT product_id, product_name, ROUND(SUM(revenue_kgs),2) AS revenue_kgs, COUNT(*) AS n_rows
FROM \`$P.marts.sales_overview\`
WHERE transaction_date BETWEEN '2026-07-01' AND '2026-07-31'
  AND LOWER(product_name) LIKE '%sun spray%'
GROUP BY product_id, product_name ORDER BY revenue_kgs DESC"

q "S3 витрина: тот же товар по ИМЕНИ (как рисует график Топ-20)" "
SELECT product_name, ROUND(SUM(revenue_kgs),2) AS revenue_kgs, COUNT(DISTINCT product_id) AS n_product_ids
FROM \`$P.marts.sales_overview\`
WHERE transaction_date BETWEEN '2026-07-01' AND '2026-07-31'
  AND LOWER(product_name) LIKE '%birch juice%sun spray%'
GROUP BY product_name ORDER BY revenue_kgs DESC"

q "S4 схема витрины sales_overview — есть ли document_owner_employee_id и как назван менеджер" "
SELECT column_name, data_type FROM \`$P.marts\`.INFORMATION_SCHEMA.COLUMNS
WHERE table_name = 'sales_overview' ORDER BY ordinal_position"

echo
gcloud auth list 2>&1 | head -4
echo "=== END $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
