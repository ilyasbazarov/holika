WITH classified AS (
  SELECT
    CASE
      WHEN sales_channel_id IS NULL
       AND COALESCE(sales_channel_name, '') IN ('Розница', 'Комиссия')
        THEN 'perimeter'
      ELSE 'sales'
    END AS bucket
  FROM `msklad-bi-prod.core.fact_sales_profit`
)
SELECT bucket, COUNT(*) AS n
FROM classified
GROUP BY bucket
ORDER BY bucket;
