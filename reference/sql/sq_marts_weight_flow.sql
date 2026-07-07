-- =============================================================================
-- marts.weight_flow
-- Scheduled Query: ежедневно
-- Вес принятых товаров (inbound) и отгруженных (outbound) по датам.
-- Используется для KPI кладовщиков.
-- Покрытие ~32.6% — растёт по мере заполнения weight в МойСклад.
-- =============================================================================

CREATE OR REPLACE TABLE `msklad-bi-prod.marts.weight_flow` AS

WITH

outbound AS (
  SELECT
    f.transaction_date                                    AS flow_date,
    DATE_TRUNC(f.transaction_date, WEEK(SATURDAY))        AS week_start,
    DATE_TRUNC(f.transaction_date, MONTH)                 AS month_start,
    'outbound'                                            AS flow_direction,
    ROUND(SUM(f.sell_quantity * COALESCE(p.weight, 0)), 2) AS weight_kg,
    COUNT(*)                                              AS positions_total,
    COUNTIF(COALESCE(p.weight, 0) > 0)                   AS positions_with_weight,
    ROUND(
      SAFE_DIVIDE(COUNTIF(COALESCE(p.weight, 0) > 0), COUNT(*)) * 100, 1
    )                                                     AS weight_coverage_pct
  FROM `msklad-bi-prod.core.fact_sales_profit` f
  LEFT JOIN `msklad-bi-prod.core.dim_products` p
    ON f.product_id = p.product_id
  GROUP BY f.transaction_date
),

inbound AS (
  SELECT
    pu.order_date                                          AS flow_date,
    DATE_TRUNC(pu.order_date, WEEK(SATURDAY))              AS week_start,
    DATE_TRUNC(pu.order_date, MONTH)                       AS month_start,
    'inbound'                                              AS flow_direction,
    ROUND(SUM(pu.quantity_shipped * COALESCE(p.weight, 0)), 2) AS weight_kg,
    COUNT(*)                                               AS positions_total,
    COUNTIF(COALESCE(p.weight, 0) > 0)                    AS positions_with_weight,
    ROUND(
      SAFE_DIVIDE(COUNTIF(COALESCE(p.weight, 0) > 0), COUNT(*)) * 100, 1
    )                                                      AS weight_coverage_pct
  FROM `msklad-bi-prod.core.fact_purchases` pu
  LEFT JOIN `msklad-bi-prod.core.dim_products` p
    ON pu.product_id = p.product_id
  WHERE pu.status_name IN ('Прибыл', 'Прибыл частично')
    AND pu.quantity_shipped > 0
  GROUP BY pu.order_date
)

SELECT * FROM outbound
UNION ALL
SELECT * FROM inbound
ORDER BY flow_date DESC, flow_direction;
