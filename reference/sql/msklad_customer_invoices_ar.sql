-- FILE: reference/sql/msklad_customer_invoices_ar.sql
-- Снимок Custom Query Looker Studio. Источник: msklad_customer_invoices_ar
-- Снят: 2026-07-30, предоставлен владельцем текстом (ADR-085 §8, задача LS-QUERY-SNAPSHOT)
-- Страница дашборда: Операционка (снято владельцем 2026-07-30)
-- Период: отсутствует, параметры дашборда не используются (снимок «на сейчас»)
-- Наблюдение: два независимых фильтра на одно понятие (total_unpaid_kgs > 0 и
--             state_name != 'Оплачено'); при NULL в state_name строка выпадает молча
-- Это поверхность пары Q-82, карту которой снимает SOURCE-MAP-INVOICES.
-- Текст ниже дословный, правки не вносились.

SELECT
  agent_name,
  country,
  state_name,
  invoice_count,
  total_invoiced_kgs,
  total_paid_kgs,
  total_unpaid_kgs,
  overdue_count
FROM `msklad-bi-prod.marts.customer_invoices_ar`
WHERE total_unpaid_kgs > 0
  AND state_name != 'Оплачено'
