-- FILE: sq_marts_customer_invoices_ar_stamped_2026-08-13.sql
-- Готовый цельный текст под вариант «две колонки» (marts_build_stamp_form_adj_2026-08-13.md §1).
-- База: reference/sql/sq_marts_customer_invoices_ar.sql (снапшот 2026-07-07), вставка
-- перед FROM (marts_build_stamp_2026-08-10.md:97-122). НЕ применено ни к одному transferConfig —
-- предмет этого файла есть готовый текст, применение вне scope MARTS-BUILD-STAMP-PREP (класс B).

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
  )                                   AS overdue_count,
  CURRENT_TIMESTAMP()                 AS _marts_built_at,
  (SELECT MAX(_loaded_at)
     FROM `msklad-bi-prod.core.fact_customer_invoices`) AS _source_max_loaded_at
FROM `msklad-bi-prod.core.fact_customer_invoices` i
LEFT JOIN `msklad-bi-prod.core.dim_counterparties` c
  ON i.agent_id = c.agent_id AND c.scd2_is_current = TRUE
GROUP BY
  i.agent_id, i.agent_name, c.country,
  i.state_name, i.state_id
ORDER BY total_unpaid_kgs DESC
