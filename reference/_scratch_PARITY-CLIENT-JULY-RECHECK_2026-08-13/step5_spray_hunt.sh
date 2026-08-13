#!/usr/bin/env bash
set -u
P=msklad-bi-prod
echo "=== START $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
gcloud auth list 2>&1 | head -4
q() { echo; echo "--- $1 ---"; bq query --project_id=$P --use_legacy_sql=false --format=prettyjson -n 300 "$2" 2>&1; }

q "H1 все товары со словом spray в витрине за июль" "
SELECT product_id, product_name, ROUND(SUM(revenue_kgs),2) AS revenue_kgs
FROM \`$P.marts.sales_overview\`
WHERE transaction_date BETWEEN '2026-07-01' AND '2026-07-31'
  AND LOWER(product_name) LIKE '%spray%'
GROUP BY product_id, product_name ORDER BY revenue_kgs DESC"

q "H2 есть ли в витрине за июль строка ровно на 27835.21" "
SELECT product_id, product_name, ROUND(SUM(revenue_kgs),2) AS revenue_kgs
FROM \`$P.marts.sales_overview\`
WHERE transaction_date BETWEEN '2026-07-01' AND '2026-07-31'
GROUP BY product_id, product_name
HAVING ABS(ROUND(SUM(revenue_kgs),2) - 27835.21) < 0.02"

q "H3 топ-25 товаров витрины за июль (что рисует график)" "
SELECT product_name, ROUND(SUM(revenue_kgs),2) AS revenue_kgs
FROM \`$P.marts.sales_overview\`
WHERE transaction_date BETWEEN '2026-07-01' AND '2026-07-31'
GROUP BY product_name ORDER BY revenue_kgs DESC LIMIT 25"

echo
gcloud auth list 2>&1 | head -4
echo "=== END $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
