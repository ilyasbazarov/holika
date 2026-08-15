-- П3: переснятие базовых чисел §5 СВОИМ запросом непосредственно перед правкой (мандат SALES-OVERVIEW-OWNER-SWITCH)
-- (1) июль по менеджеру (владелец документа) — сверка с эталоном клиента
SELECT
  'jul_by_document_owner' AS metric,
  COALESCE(e.full_name, 'Не указан') AS manager_name,
  ROUND(SUM(f.revenue_kgs), 2) AS revenue_kgs
FROM `msklad-bi-prod.core.fact_sales_profit` f
LEFT JOIN `msklad-bi-prod.core.dim_employees` e
  ON f.document_owner_employee_id = e.employee_id
WHERE f.transaction_date >= '2026-07-01' AND f.transaction_date < '2026-08-01'
GROUP BY manager_name
ORDER BY revenue_kgs DESC;

-- (2) суммарная выручка по периодам (июль/май/апрель/вся история)
SELECT
  'jul' AS period, ROUND(SUM(revenue_kgs), 2) AS revenue_kgs
FROM `msklad-bi-prod.core.fact_sales_profit`
WHERE transaction_date >= '2026-07-01' AND transaction_date < '2026-08-01'
UNION ALL
SELECT 'may', ROUND(SUM(revenue_kgs), 2)
FROM `msklad-bi-prod.core.fact_sales_profit`
WHERE transaction_date >= '2026-05-01' AND transaction_date < '2026-06-01'
UNION ALL
SELECT 'apr', ROUND(SUM(revenue_kgs), 2)
FROM `msklad-bi-prod.core.fact_sales_profit`
WHERE transaction_date >= '2026-04-01' AND transaction_date < '2026-05-01'
UNION ALL
SELECT 'all_history', ROUND(SUM(revenue_kgs), 2)
FROM `msklad-bi-prod.core.fact_sales_profit`;

-- (3) апрель по менеджеру контрагента (историческая ветка, должна остаться без изменений)
SELECT
  'apr_by_agent_owner' AS metric,
  COALESCE(e.full_name, 'Не указан') AS manager_name,
  ROUND(SUM(f.revenue_kgs), 2) AS revenue_kgs
FROM `msklad-bi-prod.core.fact_sales_profit` f
LEFT JOIN `msklad-bi-prod.core.dim_counterparties` c
  ON f.agent_id = c.agent_id AND c.scd2_is_current = TRUE
LEFT JOIN `msklad-bi-prod.core.dim_employees` e
  ON c.owner_employee_id = e.employee_id
WHERE f.transaction_date >= '2026-04-01' AND f.transaction_date < '2026-05-01'
GROUP BY manager_name
ORDER BY revenue_kgs DESC;

-- (4) май по владельцу документа (ожидаемый новый разрез)
SELECT
  'may_by_document_owner' AS metric,
  COALESCE(e.full_name, 'Не указан') AS manager_name,
  ROUND(SUM(f.revenue_kgs), 2) AS revenue_kgs
FROM `msklad-bi-prod.core.fact_sales_profit` f
LEFT JOIN `msklad-bi-prod.core.dim_employees` e
  ON f.document_owner_employee_id = e.employee_id
WHERE f.transaction_date >= '2026-05-01' AND f.transaction_date < '2026-06-01'
GROUP BY manager_name
ORDER BY revenue_kgs DESC;
