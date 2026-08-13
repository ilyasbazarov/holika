#!/usr/bin/env bash
# PARITY-CLIENT-JULY-RECHECK — шаг 1, read-only замер по трём замечаниям клиента.
# Класс A: только SELECT, ни одной записи. ADR-055/063: date -u и gcloud auth list
# первой И последней командой.
set -u
P=msklad-bi-prod

echo "=== START $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
gcloud auth list 2>&1 | head -5

q() { echo; echo "--- $1 ---"; bq query --project_id=$P --use_legacy_sql=false --format=prettyjson -n 200 "$2" 2>&1; }

q "A1 возвраты core.fact_returns за июль-2026 (все контрагенты)" "
SELECT COUNT(*) AS n_rows, ROUND(SUM(sum_kgs),2) AS sum_kgs
FROM \`$P.core.fact_returns\`
WHERE return_date BETWEEN '2026-07-01' AND '2026-07-31'"

q "A2 возвраты за окно 2025-08-12..2026-08-13" "
SELECT COUNT(*) AS n_rows, ROUND(SUM(sum_kgs),2) AS sum_kgs
FROM \`$P.core.fact_returns\`
WHERE return_date BETWEEN '2025-08-12' AND '2026-08-13'"

q "A3 гипотеза живого запроса: возвраты за 365 суток, но ТОЛЬКО по контрагентам с продажами в июле" "
WITH sales_agents AS (
  SELECT DISTINCT agent_id FROM \`$P.core.fact_sales_profit\`
  WHERE transaction_date BETWEEN '2026-07-01' AND '2026-07-31'
)
SELECT
  ROUND(SUM(CASE WHEN r.return_date BETWEEN '2026-07-01' AND '2026-07-31' THEN r.sum_kgs END),2) AS july_only,
  ROUND(SUM(CASE WHEN r.return_date > DATE_SUB(DATE '2026-07-31', INTERVAL 365 DAY) AND r.return_date <= '2026-07-31' THEN r.sum_kgs END),2) AS rolling365_to_jul31,
  ROUND(SUM(r.sum_kgs),2) AS all_history
FROM \`$P.core.fact_returns\` r
JOIN sales_agents s USING (agent_id)"

q "A4 то же для окна 2025-08-12..2026-08-13 (контрагенты с продажами в этом окне)" "
WITH sales_agents AS (
  SELECT DISTINCT agent_id FROM \`$P.core.fact_sales_profit\`
  WHERE transaction_date BETWEEN '2025-08-12' AND '2026-08-13'
)
SELECT
  ROUND(SUM(CASE WHEN r.return_date BETWEEN '2025-08-12' AND '2026-08-13' THEN r.sum_kgs END),2) AS window_only,
  ROUND(SUM(r.sum_kgs),2) AS all_history
FROM \`$P.core.fact_returns\` r
JOIN sales_agents s USING (agent_id)"

q "A5 вся история возвратов без фильтра контрагента" "
SELECT MIN(return_date) AS min_d, MAX(return_date) AS max_d,
       COUNT(*) AS n_rows, ROUND(SUM(sum_kgs),2) AS sum_all
FROM \`$P.core.fact_returns\`"

q "B1 поиск товара Round Lab Birch Juice Sun Spray в продажах июля" "
SELECT f.product_id, ANY_VALUE(p.product_name) AS product_name,
       COUNT(*) AS n_rows, ROUND(SUM(f.revenue_kgs),2) AS revenue_kgs
FROM \`$P.core.fact_sales_profit\` f
LEFT JOIN \`$P.core.dim_products\` p ON f.product_id = p.product_id
WHERE f.transaction_date BETWEEN '2026-07-01' AND '2026-07-31'
  AND LOWER(p.product_name) LIKE '%birch juice%'
GROUP BY f.product_id ORDER BY revenue_kgs DESC"

q "B2 тот же товар — разрез по каналу и типу сущности" "
SELECT ANY_VALUE(p.product_name) AS product_name, f.sales_channel_name, f.entity_type,
       COUNT(*) AS n_rows, ROUND(SUM(f.revenue_kgs),2) AS revenue_kgs
FROM \`$P.core.fact_sales_profit\` f
LEFT JOIN \`$P.core.dim_products\` p ON f.product_id = p.product_id
WHERE f.transaction_date BETWEEN '2026-07-01' AND '2026-07-31'
  AND LOWER(p.product_name) LIKE '%birch juice%'
GROUP BY f.sales_channel_name, f.entity_type ORDER BY revenue_kgs DESC"

q "B3 возвраты по этому товару за июль" "
SELECT ANY_VALUE(p.product_name) AS product_name,
       COUNT(*) AS n_rows, ROUND(SUM(r.sum_kgs),2) AS return_sum_kgs
FROM \`$P.core.fact_returns\` r
LEFT JOIN \`$P.core.dim_products\` p ON r.product_id = p.product_id
WHERE r.return_date BETWEEN '2026-07-01' AND '2026-07-31'
  AND LOWER(p.product_name) LIKE '%birch juice%'
GROUP BY r.product_id"

q "B4 контроль: MEDICUBE AGE-R BOOSTER PRO YELLOW за июль (сошёлся у клиента)" "
SELECT ANY_VALUE(p.product_name) AS product_name, f.sales_channel_name,
       COUNT(*) AS n_rows, ROUND(SUM(f.revenue_kgs),2) AS revenue_kgs
FROM \`$P.core.fact_sales_profit\` f
LEFT JOIN \`$P.core.dim_products\` p ON f.product_id = p.product_id
WHERE f.transaction_date BETWEEN '2026-07-01' AND '2026-07-31'
  AND LOWER(p.product_name) LIKE '%age-r booster pro%'
GROUP BY f.sales_channel_name ORDER BY revenue_kgs DESC"

q "C1 июль по менеджеру КОНТРАГЕНТА (как считает витрина сегодня)" "
SELECT e.full_name AS manager_name, ROUND(SUM(f.revenue_kgs),2) AS revenue_kgs
FROM \`$P.core.fact_sales_profit\` f
LEFT JOIN \`$P.core.dim_counterparties\` c ON f.agent_id = c.agent_id AND c.scd2_is_current = TRUE
LEFT JOIN \`$P.core.dim_employees\` e ON c.owner_employee_id = e.employee_id
WHERE f.transaction_date BETWEEN '2026-07-01' AND '2026-07-31'
GROUP BY manager_name ORDER BY revenue_kgs DESC"

q "C2 июль по ВЛАДЕЛЬЦУ ДОКУМЕНТА (новое поле, как режет МойСклад)" "
SELECT e.full_name AS manager_name, ROUND(SUM(f.revenue_kgs),2) AS revenue_kgs,
       COUNT(*) AS n_rows
FROM \`$P.core.fact_sales_profit\` f
LEFT JOIN \`$P.core.dim_employees\` e ON f.document_owner_employee_id = e.employee_id
WHERE f.transaction_date BETWEEN '2026-07-01' AND '2026-07-31'
GROUP BY manager_name ORDER BY revenue_kgs DESC"

q "C3 заполненность нового поля за июль" "
SELECT COUNTIF(document_owner_employee_id IS NULL) AS null_rows,
       COUNTIF(document_owner_employee_id IS NOT NULL) AS filled_rows,
       COUNT(*) AS total_rows
FROM \`$P.core.fact_sales_profit\`
WHERE transaction_date BETWEEN '2026-07-01' AND '2026-07-31'"

echo
gcloud auth list 2>&1 | head -5
echo "=== END $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
