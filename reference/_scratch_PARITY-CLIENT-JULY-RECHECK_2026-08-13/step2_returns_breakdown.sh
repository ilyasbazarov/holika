#!/usr/bin/env bash
# PARITY-CLIENT-JULY-RECHECK — шаг 2: разложение июльских возвратов и товарные строки.
# Класс A: только SELECT. Колонка имени товара — dim_products.name (не product_name).
set -u
P=msklad-bi-prod

echo "=== START $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
gcloud auth list 2>&1 | head -4

q() { echo; echo "--- $1 ---"; bq query --project_id=$P --use_legacy_sql=false --format=prettyjson -n 300 "$2" 2>&1; }

q "R1 июльские возвраты — разрез по return_type и has_basis" "
SELECT return_type, has_basis, COUNT(*) AS n_rows,
       COUNT(DISTINCT return_id) AS n_distinct_ids,
       ROUND(SUM(sum_kgs),2) AS sum_kgs
FROM \`$P.core.fact_returns\`
WHERE return_date BETWEEN '2026-07-01' AND '2026-07-31'
GROUP BY return_type, has_basis ORDER BY sum_kgs DESC"

q "R2 дубли: один return_id встречается более одного раза" "
SELECT COUNT(*) AS dup_groups, ROUND(SUM(dup_sum),2) AS dup_excess_kgs
FROM (
  SELECT return_id, COUNT(*) AS c, SUM(sum_kgs) - MIN(sum_kgs) AS dup_sum
  FROM \`$P.core.fact_returns\`
  WHERE return_date BETWEEN '2026-07-01' AND '2026-07-31'
  GROUP BY return_id HAVING COUNT(*) > 1)"

q "R3 июльские возвраты по датам" "
SELECT return_date, COUNT(*) AS n_rows, ROUND(SUM(sum_kgs),2) AS sum_kgs
FROM \`$P.core.fact_returns\`
WHERE return_date BETWEEN '2026-07-01' AND '2026-07-31'
GROUP BY return_date ORDER BY return_date"

q "R4 топ-15 июльских возвратов построчно" "
SELECT r.return_id, r.return_type, r.return_date, r.quantity,
       ROUND(r.sum_kgs,2) AS sum_kgs, c.name AS agent_name, p.name AS product_name
FROM \`$P.core.fact_returns\` r
LEFT JOIN \`$P.core.dim_counterparties\` c ON r.agent_id = c.agent_id AND c.scd2_is_current = TRUE
LEFT JOIN \`$P.core.dim_products\` p ON r.product_id = p.product_id
WHERE r.return_date BETWEEN '2026-07-01' AND '2026-07-31'
ORDER BY r.sum_kgs DESC LIMIT 15"

q "R5 июльские возвраты по контрагентам" "
SELECT c.name AS agent_name, COUNT(*) AS n_rows, ROUND(SUM(r.sum_kgs),2) AS sum_kgs
FROM \`$P.core.fact_returns\` r
LEFT JOIN \`$P.core.dim_counterparties\` c ON r.agent_id = c.agent_id AND c.scd2_is_current = TRUE
WHERE r.return_date BETWEEN '2026-07-01' AND '2026-07-31'
GROUP BY agent_name ORDER BY sum_kgs DESC"

q "B1 Round Lab Birch Juice — продажи июля, разрез по каналу" "
SELECT p.name AS product_name, f.sales_channel_name, f.entity_type,
       COUNT(*) AS n_rows, ROUND(SUM(f.revenue_kgs),2) AS revenue_kgs
FROM \`$P.core.fact_sales_profit\` f
JOIN \`$P.core.dim_products\` p ON f.product_id = p.product_id
WHERE f.transaction_date BETWEEN '2026-07-01' AND '2026-07-31'
  AND LOWER(p.name) LIKE '%birch juice%'
GROUP BY product_name, f.sales_channel_name, f.entity_type ORDER BY revenue_kgs DESC"

q "B2 Round Lab Birch Juice — возвраты июля" "
SELECT p.name AS product_name, COUNT(*) AS n_rows, ROUND(SUM(r.sum_kgs),2) AS return_sum_kgs
FROM \`$P.core.fact_returns\` r
JOIN \`$P.core.dim_products\` p ON r.product_id = p.product_id
WHERE r.return_date BETWEEN '2026-07-01' AND '2026-07-31'
  AND LOWER(p.name) LIKE '%birch juice%'
GROUP BY product_name"

q "B3 контроль MEDICUBE AGE-R BOOSTER PRO — продажи июля по каналу" "
SELECT p.name AS product_name, f.sales_channel_name,
       COUNT(*) AS n_rows, ROUND(SUM(f.revenue_kgs),2) AS revenue_kgs
FROM \`$P.core.fact_sales_profit\` f
JOIN \`$P.core.dim_products\` p ON f.product_id = p.product_id
WHERE f.transaction_date BETWEEN '2026-07-01' AND '2026-07-31'
  AND LOWER(p.name) LIKE '%age-r booster pro%'
GROUP BY product_name, f.sales_channel_name ORDER BY revenue_kgs DESC"

q "B4 MEDICUBE — возвраты июля" "
SELECT p.name AS product_name, COUNT(*) AS n_rows, ROUND(SUM(r.sum_kgs),2) AS return_sum_kgs
FROM \`$P.core.fact_returns\` r
JOIN \`$P.core.dim_products\` p ON r.product_id = p.product_id
WHERE r.return_date BETWEEN '2026-07-01' AND '2026-07-31'
  AND LOWER(p.name) LIKE '%age-r booster pro%'
GROUP BY product_name"

echo
gcloud auth list 2>&1 | head -4
echo "=== END $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
