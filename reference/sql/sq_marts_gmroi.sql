CREATE OR REPLACE TABLE `msklad-bi-prod.marts.gmroi` AS
WITH periods AS (SELECT 30 AS days UNION ALL SELECT 90),
sales_agg AS (
  SELECT p.days, f.product_id, SUM(f.revenue_kgs) AS revenue_kgs, SUM(COALESCE(f.cogs_kgs,0)) AS cogs_kgs, SUM(f.revenue_kgs)-SUM(COALESCE(f.cogs_kgs,0)) AS gross_profit_kgs
  FROM `msklad-bi-prod.core.fact_sales_profit` f CROSS JOIN periods p
  WHERE f.transaction_date >= DATE_SUB(CURRENT_DATE(), INTERVAL p.days DAY)
  GROUP BY p.days, f.product_id),
inventory_agg AS (
  SELECT p.days, i.product_id, COUNT(*) AS snapshot_count, AVG(i.stock * i.cost_kgs) AS avg_inventory_kgs
  FROM `msklad-bi-prod.core.fact_inventory` i CROSS JOIN periods p
  WHERE i.date_snapshot >= DATE_SUB(CURRENT_DATE(), INTERVAL p.days DAY)
  GROUP BY p.days, i.product_id),
latest_fx AS (
  SELECT rate_kgs_per_usd FROM `msklad-bi-prod.core.dim_fx_rates`
  WHERE date = (SELECT MAX(date) FROM `msklad-bi-prod.core.dim_fx_rates`))
SELECT s.days AS period_days, s.product_id, p.name AS product_name, p.product_folder, p.parent_product_id,
  ROUND(s.revenue_kgs,2) AS revenue_kgs, ROUND(s.cogs_kgs,2) AS cogs_kgs, ROUND(s.gross_profit_kgs,2) AS gross_profit_kgs,
  ROUND(SAFE_DIVIDE(s.gross_profit_kgs,s.revenue_kgs),4) AS gross_margin_pct, ROUND(i.avg_inventory_kgs,2) AS avg_inventory_kgs,
  COALESCE(i.snapshot_count,0) AS snapshot_count,
  ROUND(SAFE_DIVIDE(s.gross_profit_kgs,NULLIF(i.avg_inventory_kgs,0))*(365.0/s.days),2) AS gmroi,
  ROUND(s.revenue_kgs/fx.rate_kgs_per_usd,2) AS revenue_usd, ROUND(s.gross_profit_kgs/fx.rate_kgs_per_usd,2) AS gross_profit_usd,
  ROUND(COALESCE(i.avg_inventory_kgs,0)/fx.rate_kgs_per_usd,2) AS avg_inventory_usd, fx.rate_kgs_per_usd,
  CASE WHEN i.avg_inventory_kgs IS NULL THEN TRUE ELSE FALSE END AS is_inventory_missing,
  CASE WHEN s.cogs_kgs=0 THEN TRUE ELSE FALSE END AS is_cogs_zero,
  CURRENT_TIMESTAMP() AS _mart_refreshed_at
FROM sales_agg s
LEFT JOIN `msklad-bi-prod.core.dim_products` p ON s.product_id=p.product_id
LEFT JOIN inventory_agg i ON s.product_id=i.product_id AND s.days=i.days
CROSS JOIN latest_fx fx
