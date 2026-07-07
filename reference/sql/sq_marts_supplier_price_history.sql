CREATE OR REPLACE TABLE `msklad-bi-prod.marts.supplier_price_history`
PARTITION BY order_date
CLUSTER BY supplier_id, product_id
AS
SELECT
  p.order_date,
  p.product_id,
  prod.name AS product_name,
  prod.product_folder AS product_folder,
  p.supplier_id,
  sup.name AS supplier_name,
  p.status_name,
  p.quantity_ordered,
  p.price_kgs,
  ROUND(p.price_kgs / COALESCE(fx.rate_kgs_per_usd,
    (SELECT rate_kgs_per_usd FROM `msklad-bi-prod.core.dim_fx_rates`
     ORDER BY date DESC LIMIT 1)), 2) AS price_usd,
  p.sum_kgs,
  COALESCE(fx.rate_kgs_per_usd,
    (SELECT rate_kgs_per_usd FROM `msklad-bi-prod.core.dim_fx_rates`
     ORDER BY date DESC LIMIT 1)) AS fx_rate_used,
  CURRENT_TIMESTAMP() AS _mart_refreshed_at
FROM `msklad-bi-prod.core.fact_purchases` p
LEFT JOIN `msklad-bi-prod.core.dim_products` prod
  ON p.product_id = prod.product_id
LEFT JOIN `msklad-bi-prod.core.dim_counterparties` sup
  ON p.supplier_id = sup.agent_id
  AND sup.scd2_is_current = TRUE
LEFT JOIN `msklad-bi-prod.core.dim_fx_rates` fx
  ON fx.date = p.order_date
WHERE p.price_kgs > 0
