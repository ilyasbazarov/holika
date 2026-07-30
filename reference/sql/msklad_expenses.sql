-- FILE: reference/sql/msklad_expenses.sql
-- Снимок Custom Query Looker Studio. Источник: msklad_expenses
-- Снят: 2026-07-30, предоставлен владельцем текстом (ADR-085 §8, задача LS-QUERY-SNAPSHOT)
-- Страница дашборда: Расходы (снято владельцем 2026-07-30)
-- Период: берётся из параметров дашборда (@DS_START_DATE/@DS_END_DATE)
-- Наблюдение: несёт total_sum_usd, то есть исходящая конвертация KGS→USD уже стоит
--             на клиентской поверхности (ветка FX, Q-56/Q-66/Q-69, owner-gated)
-- Текст ниже дословный, правки не вносились.

SELECT
  moment,
  month_start,
  week_start,
  year_month,
  expense_item_name,
  agent_name,
  project_name,
  sales_channel_name,
  payment_count,
  total_sum_kgs,
  total_sum_usd
FROM `msklad-bi-prod.marts.expenses`
WHERE DATE(moment) >= PARSE_DATE('%Y%m%d', @DS_START_DATE)
  AND DATE(moment) <= PARSE_DATE('%Y%m%d', @DS_END_DATE)
