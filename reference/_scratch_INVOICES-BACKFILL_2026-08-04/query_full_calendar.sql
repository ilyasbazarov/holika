WITH calendar AS (
  SELECT day AS doc_date
  FROM UNNEST(GENERATE_DATE_ARRAY('2026-06-05', '2026-08-03')) AS day
),
counts AS (
  SELECT
    moment AS doc_date,
    COUNT(*) AS row_count
  FROM `msklad-bi-prod.core.fact_customer_invoices`
  WHERE moment BETWEEN '2026-06-05' AND '2026-08-03'
  GROUP BY doc_date
)
SELECT
  c.doc_date,
  IFNULL(k.row_count, 0) AS row_count
FROM calendar c
LEFT JOIN counts k USING (doc_date)
ORDER BY c.doc_date
