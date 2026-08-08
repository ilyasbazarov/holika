
MERGE `msklad-bi-prod.core.fact_sales_profit` T
USING (
  SELECT
    TO_HEX(MD5(CONCAT(s.demand_id, '|', s.position_id)))            AS transaction_id,
    DATE(PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%E3S', s.transaction_date_raw), 'Asia/Bishkek')                                                   AS transaction_date,
    s.product_id,
    s.entity_type,
    s.discount,
    s.agent_id,
    s.quantity                                                      AS sell_quantity,
    CAST(0.0 AS FLOAT64)                                            AS return_quantity,
    s.revenue_kgs                                                   AS sell_sum_kgs,
    CAST(0.0 AS FLOAT64)                                            AS return_sum_kgs,
    s.revenue_kgs                                                   AS revenue_kgs,
    CASE
      WHEN b.cogs_kgs IS NOT NULL AND b.sell_sum_kgs > 0
        THEN ROUND(b.cogs_kgs * SAFE_DIVIDE(s.revenue_kgs, NULLIF(b.sell_sum_kgs, 0)), 4)
      ELSE NULL
    END                                                             AS cogs_kgs,
    CASE
      WHEN b.cogs_kgs IS NOT NULL AND b.sell_sum_kgs > 0
        THEN ROUND(s.revenue_kgs - b.cogs_kgs * SAFE_DIVIDE(s.revenue_kgs, NULLIF(b.sell_sum_kgs, 0)), 4)
      ELSE NULL
    END                                                             AS margin_kgs,
    ROUND(SAFE_DIVIDE(s.revenue_kgs, fx.rate_kgs_per_usd), 4)       AS revenue_usd,
    CASE
      WHEN b.cogs_kgs IS NOT NULL AND b.sell_sum_kgs > 0 AND fx.rate_kgs_per_usd IS NOT NULL
        THEN ROUND(SAFE_DIVIDE(b.cogs_kgs * SAFE_DIVIDE(s.revenue_kgs, NULLIF(b.sell_sum_kgs, 0)), fx.rate_kgs_per_usd), 4)
      ELSE NULL
    END                                                             AS cogs_usd,
    CASE
      WHEN b.cogs_kgs IS NOT NULL AND b.sell_sum_kgs > 0 AND fx.rate_kgs_per_usd IS NOT NULL
        THEN ROUND(SAFE_DIVIDE(s.revenue_kgs - b.cogs_kgs * SAFE_DIVIDE(s.revenue_kgs, NULLIF(b.sell_sum_kgs, 0)), fx.rate_kgs_per_usd), 4)
      ELSE NULL
    END                                                             AS margin_usd,
    s.sales_channel_id,
    s.sales_channel_name,
    s.project_id,
    s.project_name,
    CURRENT_TIMESTAMP()                                             AS _loaded_at
  FROM `msklad-bi-prod.stg_msklad.fact_sales_staging` s
  LEFT JOIN `msklad-bi-prod.core.fact_sales_profit_byvariant_backup` b
    ON  s.product_id = b.product_id
    AND DATE_TRUNC(
          DATE(PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%E3S', s.transaction_date_raw), 'Asia/Bishkek'),
          WEEK(SATURDAY)
        ) = b._week_start
  LEFT JOIN `msklad-bi-prod.core.dim_fx_rates` fx
    ON  DATE(PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%E3S', s.transaction_date_raw), 'Asia/Bishkek') = fx.date
) S
ON  T.transaction_id   = S.transaction_id
AND T.transaction_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)

WHEN MATCHED THEN UPDATE SET
  T.sell_quantity   = S.sell_quantity,
  T.return_quantity = S.return_quantity,
  T.sell_sum_kgs    = S.sell_sum_kgs,
  T.return_sum_kgs  = S.return_sum_kgs,
  T.revenue_kgs     = S.revenue_kgs,
  T.cogs_kgs        = S.cogs_kgs,
  T.margin_kgs      = S.margin_kgs,
  T.revenue_usd     = S.revenue_usd,
  T.cogs_usd        = S.cogs_usd,
  T.margin_usd      = S.margin_usd,
  T.sales_channel_id   = S.sales_channel_id,
  T.sales_channel_name = S.sales_channel_name,
  T.project_id         = S.project_id,
  T.project_name       = S.project_name,
  T.discount        = S.discount,
  T._loaded_at      = S._loaded_at

WHEN NOT MATCHED THEN INSERT (
  transaction_id,
  transaction_date,
  product_id,
  entity_type,
  agent_id,
  sell_quantity,
  return_quantity,
  sell_sum_kgs,
  return_sum_kgs,
  revenue_kgs,
  cogs_kgs,
  margin_kgs,
  revenue_usd,
  cogs_usd,
  margin_usd,
  sales_channel_id,
  sales_channel_name,
  project_id,
  project_name,
  discount,
  _loaded_at
) VALUES (
  S.transaction_id,
  S.transaction_date,
  S.product_id,
  S.entity_type,
  S.agent_id,
  S.sell_quantity,
  S.return_quantity,
  S.sell_sum_kgs,
  S.return_sum_kgs,
  S.revenue_kgs,
  S.cogs_kgs,
  S.margin_kgs,
  S.revenue_usd,
  S.cogs_usd,
  S.margin_usd,
  S.sales_channel_id,
  S.sales_channel_name,
  S.project_id,
  S.project_name,
  S.discount,
  S._loaded_at
)

-- SALES-REFRESH-WINDOW (ADR-144 §8, узкая форма): строки, исчезнувшие из источника внутри
-- окна выборки, удаляются. Условие DELETE обязано ПОВТОРЯТЬ границу окна ON явно (C2,
-- ADR-101 §7 ловушка ii) — без этого повтора `WHEN NOT MATCHED BY SOURCE` по умолчанию
-- матчит и удаляет ВСЮ историю за пределами окна (там ON тоже не находит пару), а не только
-- сироты внутри окна. window_days тот же параметр, что несёт ON — единственный параметр в
-- узкой форме, режим `topoff` с раздельными окнами выборки/MERGE этим патчем не строится.
WHEN NOT MATCHED BY SOURCE
  AND T.transaction_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)
THEN DELETE
