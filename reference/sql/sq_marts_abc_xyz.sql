CREATE OR REPLACE TABLE `msklad-bi-prod.marts.abc_xyz` AS
WITH
sales_90d AS (
  SELECT product_id, SUM(revenue_kgs) AS revenue_90d, SUM(sell_quantity) AS quantity_90d, SUM(COALESCE(margin_kgs,0)) AS margin_90d, COUNT(DISTINCT transaction_date) AS active_days
  FROM `msklad-bi-prod.core.fact_sales_profit`
  WHERE transaction_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY)
    AND revenue_kgs > 0
  GROUP BY product_id),
revenue_ranked AS (
  SELECT *, SUM(revenue_90d) OVER() AS total_revenue,
    SUM(revenue_90d) OVER(ORDER BY revenue_90d DESC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS cumulative_revenue
  FROM sales_90d),
abc AS (
  SELECT *, CASE WHEN cumulative_revenue/total_revenue<=0.8 THEN "A" WHEN cumulative_revenue/total_revenue<=0.95 THEN "B" ELSE "C" END AS abc_class
  FROM revenue_ranked),
weekly_sales AS (
  SELECT product_id, DATE_TRUNC(transaction_date,WEEK(SATURDAY)) AS week_start, SUM(sell_quantity) AS weekly_qty
  FROM `msklad-bi-prod.core.fact_sales_profit`
  WHERE transaction_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY)
    AND revenue_kgs > 0
  GROUP BY product_id, week_start),
xyz AS (
  SELECT product_id, COUNT(*) AS weeks_with_sales, AVG(weekly_qty) AS avg_weekly_qty,
    SAFE_DIVIDE(STDDEV(weekly_qty),NULLIF(AVG(weekly_qty),0)) AS cov,
    CASE WHEN SAFE_DIVIDE(STDDEV(weekly_qty),NULLIF(AVG(weekly_qty),0))<=0.5 THEN "X"
         WHEN SAFE_DIVIDE(STDDEV(weekly_qty),NULLIF(AVG(weekly_qty),0))<=1.0 THEN "Y" ELSE "Z" END AS xyz_class
  FROM weekly_sales GROUP BY product_id),
latest_fx AS (
  SELECT rate_kgs_per_usd FROM `msklad-bi-prod.core.dim_fx_rates`
  WHERE date=(SELECT MAX(date) FROM `msklad-bi-prod.core.dim_fx_rates`))
SELECT COALESCE(a.product_id,x.product_id) AS product_id, p.name AS product_name, p.article, p.product_folder, p.entity_type, p.parent_product_id,
  COALESCE(a.abc_class,"C") AS abc_class, ROUND(COALESCE(a.revenue_90d,0),2) AS revenue_90d_kgs, ROUND(COALESCE(a.margin_90d,0),2) AS margin_90d_kgs,
  COALESCE(a.quantity_90d,0) AS quantity_90d, COALESCE(a.active_days,0) AS active_days_90d,
  ROUND(COALESCE(a.revenue_90d,0)/fx.rate_kgs_per_usd,2) AS revenue_90d_usd,
  COALESCE(x.xyz_class,"Z") AS xyz_class, ROUND(COALESCE(x.cov,0),4) AS cov,
  COALESCE(x.weeks_with_sales,0) AS weeks_with_sales, ROUND(COALESCE(x.avg_weekly_qty,0),2) AS avg_weekly_qty,
  CONCAT(COALESCE(a.abc_class,"C"),COALESCE(x.xyz_class,"Z")) AS abc_xyz,
  fx.rate_kgs_per_usd, CURRENT_TIMESTAMP() AS _mart_refreshed_at
FROM abc a FULL OUTER JOIN xyz x ON a.product_id=x.product_id
LEFT JOIN `msklad-bi-prod.core.dim_products` p ON COALESCE(a.product_id,x.product_id)=p.product_id
CROSS JOIN latest_fx fx
