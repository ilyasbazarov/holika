-- Наша сторона: агрегат marts.customer_invoices_ar на момент снятия живого GET.
-- Источник колонок — reference/sql/sq_marts_customer_invoices_ar.sql (invoice_count,
-- total_invoiced_kgs, total_paid_kgs, total_unpaid_kgs, сгруппировано по контрагенту+статусу).
SELECT
  SUM(invoice_count)        AS total_invoice_count,
  ROUND(SUM(total_invoiced_kgs), 2) AS total_invoiced_kgs,
  ROUND(SUM(total_paid_kgs), 2)     AS total_paid_kgs,
  ROUND(SUM(total_unpaid_kgs), 2)   AS total_unpaid_kgs
FROM `msklad-bi-prod.marts.customer_invoices_ar`
