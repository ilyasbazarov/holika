
SELECT
  i.agent_id,
  i.agent_name,
  COALESCE(c.country, 'Не указана') AS country,
  i.state_name,
  i.state_id,
  COUNT(DISTINCT i.invoice_id)        AS invoice_count,
  ROUND(SUM(i.sum_kgs), 2)            AS total_invoiced_kgs,
  ROUND(SUM(i.payed_sum_kgs), 2)      AS total_paid_kgs,
  ROUND(SUM(i.unpaid_sum_kgs), 2)     AS total_unpaid_kgs,
  MIN(i.moment)                       AS earliest_invoice_date,
  MAX(i.moment)                       AS latest_invoice_date,
  COUNTIF(
    i.payment_planned IS NOT NULL
    AND i.payment_planned < CURRENT_DATE()
    AND i.unpaid_sum_kgs > 0
  )                                   AS overdue_count
FROM `msklad-bi-prod.core.fact_customer_invoices` i
LEFT JOIN `msklad-bi-prod.core.dim_counterparties` c
  ON i.agent_id = c.agent_id AND c.scd2_is_current = TRUE
GROUP BY
  i.agent_id, i.agent_name, c.country,
  i.state_name, i.state_id
ORDER BY total_unpaid_kgs DESC
