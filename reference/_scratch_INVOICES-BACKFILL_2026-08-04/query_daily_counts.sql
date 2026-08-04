SELECT
  moment AS doc_date,
  COUNT(*) AS row_count,
  ROUND(SUM(sum_kgs), 2) AS sum_kgs
FROM `msklad-bi-prod.core.fact_customer_invoices`
WHERE moment BETWEEN '2026-06-05' AND '2026-08-03'
GROUP BY doc_date
ORDER BY doc_date
