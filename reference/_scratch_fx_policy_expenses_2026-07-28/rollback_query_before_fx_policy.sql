WITH fx AS (
  SELECT rate_kgs_per_usd
  FROM `msklad-bi-prod.core.dim_fx_rates`
  ORDER BY date DESC
  LIMIT 1
),
src AS (
  SELECT
    p.moment,
    p.payment_type,
    p.expense_item_id,
    COALESCE(p.expense_item_name, 'Не указана') AS expense_item_name,
    p.agent_id,
    COALESCE(p.agent_name, 'Не указан')         AS agent_name,
    p.project_id,
    COALESCE(p.project_name, 'Не указан')       AS project_name,
    p.sales_channel_id,
    COALESCE(p.sales_channel_name, 'Не указан') AS sales_channel_name,
    p.sum_kgs
  FROM `msklad-bi-prod.core.fact_payments` p
  WHERE p.moment IS NOT NULL

  UNION ALL

  SELECT
    CAST(l.moment AS DATE)                      AS moment,
    'loss'                                      AS payment_type,
    l.expense_item_id,
    COALESCE(l.expense_item_name, 'Не указана') AS expense_item_name,
    l.agent_id,
    COALESCE(l.agent_name, 'Не указан')         AS agent_name,
    l.project_id,
    'Не указан'                                 AS project_name,
    l.sales_channel_id,
    'Не указан'                                 AS sales_channel_name,
    l.sum_kgs
  FROM `msklad-bi-prod.core.fact_loss` l
  WHERE l.moment IS NOT NULL
    AND l.applicable
    AND COALESCE(l.expense_item_id, '') NOT IN (
      '24c0e914-2d8c-11f1-0a80-11b0000c7043',
      '4e1c05f2-0673-11e6-a655-0cc47a342ca4',
      '8dbf9374-0a01-11e4-b9bf-002590a32f46',
      '8dbf99a0-0a01-11e4-a743-002590a32f46'
    )

  UNION ALL

  SELECT
    CAST(c.moment AS DATE)       AS moment,
    'commission'                 AS payment_type,
    CAST(NULL AS STRING)         AS expense_item_id,
    'Расходы маркетплейсов'      AS expense_item_name,
    c.agent_id,
    'Не указан'                  AS agent_name,
    CAST(NULL AS STRING)         AS project_id,
    'Не указан'                  AS project_name,
    CAST(NULL AS STRING)         AS sales_channel_id,
    'Не указан'                  AS sales_channel_name,
    c.sum_kgs
  FROM `msklad-bi-prod.core.fact_commissionreportin` c
  WHERE c.moment IS NOT NULL
)
SELECT
  s.moment,
  DATE_TRUNC(s.moment, MONTH)                     AS month_start,
  DATE_TRUNC(s.moment, WEEK(SATURDAY))            AS week_start,
  EXTRACT(YEAR FROM s.moment)                     AS year_num,
  FORMAT_DATE('%Y-%m', s.moment)                  AS year_month,
  s.payment_type,
  s.expense_item_id,
  s.expense_item_name,
  s.agent_id,
  s.agent_name,
  s.project_id,
  s.project_name,
  s.sales_channel_id,
  s.sales_channel_name,
  COUNT(*)                                        AS payment_count,
  ROUND(SUM(s.sum_kgs), 2)                        AS total_sum_kgs,
  ROUND(SUM(s.sum_kgs) / fx.rate_kgs_per_usd, 2)  AS total_sum_usd
FROM src s
LEFT JOIN fx ON TRUE
WHERE s.moment IS NOT NULL
GROUP BY
  s.moment, month_start, week_start, year_num, year_month,
  s.payment_type, s.expense_item_id, s.expense_item_name,
  s.agent_id, s.agent_name, s.project_id, s.project_name,
  s.sales_channel_id, s.sales_channel_name,
  fx.rate_kgs_per_usd
