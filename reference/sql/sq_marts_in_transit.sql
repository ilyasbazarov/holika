CREATE OR REPLACE TABLE `msklad-bi-prod.marts.in_transit`
CLUSTER BY supplier_id, product_id
AS
WITH latest_fx AS (
  SELECT rate_kgs_per_usd
  FROM `msklad-bi-prod.core.dim_fx_rates`
  ORDER BY date DESC
  LIMIT 1
)
SELECT
  p.order_name,
  p.purchase_order_id,
  p.position_id,
  p.order_date,
  p.planned_delivery_date,
  CASE
    WHEN p.planned_delivery_date IS NULL THEN NULL
    ELSE DATE_DIFF(p.planned_delivery_date, CURRENT_DATE(), DAY)
  END AS days_until_delivery,
  CASE
    WHEN p.planned_delivery_date IS NOT NULL
     AND p.planned_delivery_date < CURRENT_DATE() THEN TRUE
    ELSE FALSE
  END AS is_overdue,
  p.product_id,
  prod.name AS product_name,
  prod.product_folder AS product_folder,
  p.supplier_id,
  sup.name AS supplier_name,
  p.status_name,
  p.quantity_ordered,
  p.quantity_shipped,
  p.quantity_in_transit,
  p.price_kgs,
  p.in_transit_sum_kgs,
  ROUND(p.in_transit_sum_kgs / fx.rate_kgs_per_usd, 2) AS in_transit_sum_usd,
  fx.rate_kgs_per_usd AS fx_rate_used,
  CURRENT_TIMESTAMP() AS _mart_refreshed_at
FROM `msklad-bi-prod.core.fact_purchases` p
CROSS JOIN latest_fx fx
LEFT JOIN `msklad-bi-prod.core.dim_products` prod
  ON p.product_id = prod.product_id
LEFT JOIN `msklad-bi-prod.core.dim_counterparties` sup
  ON p.supplier_id = sup.agent_id
  AND sup.scd2_is_current = TRUE
WHERE p.status_name IN ("В пути", "Прибыл частично")
  AND p.in_transit_sum_kgs > 0
