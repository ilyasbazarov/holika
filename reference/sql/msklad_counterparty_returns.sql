-- FILE: reference/sql/msklad_counterparty_returns.sql
-- Снимок Custom Query Looker Studio. Источник: msklad_counterparty_returns
-- Снят: 2026-07-30, предоставлен владельцем текстом (ADR-085 §8, задача LS-QUERY-SNAPSHOT)
-- Страница дашборда: Операционка (снято владельцем 2026-07-30) (вставка в интерфейс — владелец, ADR-085 §9)
-- Период: продажи и возвраты берутся из параметров дашборда @DS_START_DATE/@DS_END_DATE
--          (исправлено задачей LS-COUNTERPARTY-RETURNS-FIX, приёмка ADR-085 §10, контракт периода ADR-087 §1)
-- Зерно строки: один контрагент (agent_id) за период дашборда — разрез по каналу/проекту продаж снят,
--          т.к. core.fact_returns не несёт sales_channel_id/project_id (см. LS-COUNTERPARTY-RETURNS-FIX,
--          02_ERP_CONTRACTS.md §схемы core); прежнее зерно размножало сумму возвратов по каналам/проектам.

SELECT
  c.name                                              AS counterparty_name,
  f.agent_id,
  c.country,
  COUNT(DISTINCT f.agent_id)                          AS counterparty_count,
  ROUND(SUM(f.revenue_kgs), 2)                        AS revenue_kgs,
  ROUND(SUM(COALESCE(f.margin_kgs, 0)), 2)            AS margin_kgs,
  ROUND(
    SAFE_DIVIDE(SUM(COALESCE(f.margin_kgs,0)), SUM(f.revenue_kgs)) * 100, 1
  )                                                   AS margin_pct,
  COALESCE(r.return_sum_kgs, 0)                       AS return_sum_kgs,
  ROUND(SUM(f.revenue_kgs) - COALESCE(r.return_sum_kgs, 0), 2)
                                                      AS net_revenue_kgs,
  ROUND(
    SAFE_DIVIDE(COALESCE(r.return_sum_kgs, 0), SUM(f.revenue_kgs)) * 100, 1
  )                                                   AS return_rate_pct,
  COUNT(DISTINCT f.transaction_date)                  AS active_days_count
FROM `msklad-bi-prod.core.fact_sales_profit` f
LEFT JOIN `msklad-bi-prod.core.dim_counterparties` c
  ON f.agent_id = c.agent_id AND c.scd2_is_current = TRUE
LEFT JOIN (
  SELECT agent_id, SUM(sum_kgs) AS return_sum_kgs
  FROM `msklad-bi-prod.core.fact_returns`
  WHERE return_date BETWEEN PARSE_DATE('%Y%m%d', @DS_START_DATE)
                         AND PARSE_DATE('%Y%m%d', @DS_END_DATE)
  GROUP BY agent_id
) r ON f.agent_id = r.agent_id
WHERE f.transaction_date BETWEEN PARSE_DATE('%Y%m%d', @DS_START_DATE)
                              AND PARSE_DATE('%Y%m%d', @DS_END_DATE)
GROUP BY c.name, f.agent_id, r.return_sum_kgs, c.country
ORDER BY revenue_kgs DESC
