
SELECT
  p.moment,
  DATE_TRUNC(p.moment, MONTH)                     AS month_start,
  DATE_TRUNC(p.moment, WEEK(SATURDAY))             AS week_start,
  EXTRACT(YEAR FROM p.moment)                      AS year_num,
  FORMAT_DATE('%Y-%m', p.moment)                   AS year_month,
  p.payment_type,
  p.expense_item_id,
  COALESCE(p.expense_item_name, 'Не указана')      AS expense_item_name,
  p.agent_id,
  COALESCE(p.agent_name, 'Не указан')              AS agent_name,
  p.project_id,
  COALESCE(p.project_name, 'Не указан')            AS project_name,
  p.sales_channel_id,
  COALESCE(p.sales_channel_name, 'Не указан')      AS sales_channel_name,
  COUNT(*)                                         AS payment_count,
  ROUND(SUM(p.sum_kgs), 2)                         AS total_sum_kgs,
  ROUND(SUM(p.sum_kgs) / fx.rate_kgs_per_usd, 2)  AS total_sum_usd
FROM `msklad-bi-prod.core.fact_payments` p
LEFT JOIN (
  SELECT rate_kgs_per_usd
  FROM `msklad-bi-prod.core.dim_fx_rates`
  ORDER BY date DESC
  LIMIT 1
) fx ON TRUE
WHERE p.moment IS NOT NULL
GROUP BY
  p.moment, month_start, week_start, year_num, year_month,
  p.payment_type, p.expense_item_id, p.expense_item_name,
  p.agent_id, p.agent_name, p.project_id, p.project_name,
  p.sales_channel_id, p.sales_channel_name,
  fx.rate_kgs_per_usd
ORDER BY p.moment DESC
