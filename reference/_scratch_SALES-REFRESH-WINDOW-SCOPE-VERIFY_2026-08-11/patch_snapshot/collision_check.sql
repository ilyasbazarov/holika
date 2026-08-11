SELECT COUNT(*) AS n
FROM `msklad-bi-prod.core.fact_sales_profit`
WHERE sales_channel_id IS NOT NULL
  AND COALESCE(sales_channel_name, '') IN ('Розница', 'Комиссия');
