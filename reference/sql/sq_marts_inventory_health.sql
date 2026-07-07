-- =============================================================================
-- marts.inventory_health
-- Scheduled Query: ежедневно в 05:00 UTC (07:00 KGT) — после CF-Inventory (03:00 KGT)
-- и CF-Dim (03:00 UTC).
-- CREATE OR REPLACE TABLE — полная пересборка из последнего снэпшота.
--
-- ПАТЧ v1.1 (День 2, Неделя 3):
--   + sales_90d CTE → calendar_adt_90d (сглаженный ADT для B2B анти-спайк)
--   + coverage_days_90d_calendar — дней запаса по 90д сглаженному ADT
--   + COALESCE(product_folder, 'Без категории') — defensive fallback
-- =============================================================================

CREATE OR REPLACE TABLE `msklad-bi-prod.marts.inventory_health` AS

WITH

-- Последний снэпшот остатков
latest_snapshot AS (
  SELECT *
  FROM `msklad-bi-prod.core.fact_inventory`
  WHERE date_snapshot = (
    SELECT MAX(date_snapshot)
    FROM `msklad-bi-prod.core.fact_inventory`
  )
),

-- Продажи за последние 30 дней для расчёта ADT и детектирования токсичного стока
sales_30d AS (
  SELECT
    product_id,
    SUM(sell_quantity)                                                    AS sold_quantity_30d,
    SUM(revenue_kgs)                                                      AS revenue_30d_kgs,
    COUNT(DISTINCT transaction_date)                                      AS active_days_30d,
    -- True ADT: среднедневные по АКТИВНЫМ дням (без нулевых дней)
    -- Используется для is_toxic, is_low_stock флагов
    SAFE_DIVIDE(SUM(sell_quantity), NULLIF(COUNT(DISTINCT transaction_date), 0))
                                                                          AS true_adt,
    -- Calendar ADT 30д: по календарным дням (для справки)
    SUM(sell_quantity) / 30.0                                             AS calendar_adt
  FROM `msklad-bi-prod.core.fact_sales_profit`
  WHERE transaction_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
    AND revenue_kgs > 0  -- exclude sample giveaways
  GROUP BY product_id
),

-- Продажи за последние 90 дней — сглаженный ADT для B2B
-- Нивелирует спайки разовых крупных оптовых отгрузок.
-- coverage_days_90d_calendar = quantity_available / calendar_adt_90d
-- Показывает реалистичный запас в днях без артефактов одного крупного заказа.
sales_90d AS (
  SELECT
    product_id,
    SUM(sell_quantity)          AS sold_quantity_90d,
    SUM(sell_quantity) / 90.0   AS calendar_adt_90d
  FROM `msklad-bi-prod.core.fact_sales_profit`
  WHERE transaction_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY)
    AND revenue_kgs > 0  -- exclude sample giveaways
  GROUP BY product_id
),

-- Продажи за последние 7 дней (для is_stagnant)
sales_7d AS (
  SELECT
    product_id,
    SUM(sell_quantity) AS sold_quantity_7d
  FROM `msklad-bi-prod.core.fact_sales_profit`
  WHERE transaction_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)
    AND revenue_kgs > 0  -- exclude sample giveaways
  GROUP BY product_id
),

-- Последний известный курс USD
latest_fx AS (
  SELECT rate_kgs_per_usd
  FROM `msklad-bi-prod.core.dim_fx_rates`
  WHERE date = (SELECT MAX(date) FROM `msklad-bi-prod.core.dim_fx_rates`)
)

SELECT
  -- ── Идентификаторы ──────────────────────────────────────────────────────
  i.date_snapshot,
  i.product_id,
  p.name                                                          AS product_name,
  p.article,
  COALESCE(p.product_folder, 'Без категории')                    AS product_folder,
  p.entity_type,
  p.parent_product_id,

  -- ── Остатки ──────────────────────────────────────────────────────────
  i.stock,
  i.reserve,
  i.quantity_available,
  FLOOR(i.stock_days)                                            AS stock_days,

  -- ── Финансовый срез ──────────────────────────────────────────────────
  i.cost_kgs,
  ROUND(i.stock * i.cost_kgs, 2)                                 AS frozen_capital_kgs,
  ROUND(SAFE_DIVIDE(i.stock * i.cost_kgs, fx.rate_kgs_per_usd), 2)
                                                                  AS frozen_capital_usd,

  -- ── Продажи 30д ──────────────────────────────────────────────────────
  COALESCE(s30.sold_quantity_30d, 0)                             AS sold_quantity_30d,
  COALESCE(s30.revenue_30d_kgs, 0)                               AS revenue_30d_kgs,
  COALESCE(s30.active_days_30d, 0)                               AS active_days_30d,
  COALESCE(s30.true_adt, 0)                                      AS true_adt,
  COALESCE(s30.calendar_adt, 0)                                  AS calendar_adt,
  COALESCE(s7.sold_quantity_7d, 0)                               AS sold_quantity_7d,

  -- ── Продажи 90д (сглаженные) ─────────────────────────────────────────
  COALESCE(s90.sold_quantity_90d, 0)                             AS sold_quantity_90d,
  ROUND(COALESCE(s90.calendar_adt_90d, 0), 2)                    AS calendar_adt_90d,

  -- ── Coverage Days — две версии ───────────────────────────────────────

  -- v1: True ADT 30д (операционный, чувствителен к спайкам)
  -- Показывает критичность по недавним активным дням продаж.
  -- Используется для is_low_stock флага.
  CASE
    WHEN COALESCE(s30.true_adt, 0) > 0
    THEN ROUND(i.quantity_available / s30.true_adt, 1)
    ELSE NULL
  END                                                             AS coverage_days_true_adt,

  -- v2: Calendar ADT 90д (сглаженный, анти-спайк, для B2B опта)
  -- Нивелирует разовые крупные отгрузки. Рекомендован для инвестора и стратегических решений.
  -- Пример: Dr.Althea 345 Cream: true_adt → 0.6д, calendar_90d → ~15д (реальный запас).
  CASE
    WHEN COALESCE(s90.calendar_adt_90d, 0) > 0
    THEN ROUND(i.quantity_available / s90.calendar_adt_90d, 0)
    ELSE NULL
  END                                                             AS coverage_days_90d_calendar,

  -- ── Статусные флаги ──────────────────────────────────────────────────

  -- OOS: нет доступного товара
  CASE
    WHEN i.quantity_available <= 0 THEN TRUE
    ELSE FALSE
  END                                                             AS is_oos,

  -- Токсичный сток: нет продаж за 30 дней при положительном остатке
  CASE
    WHEN (COALESCE(s30.sold_quantity_30d, 0) = 0 OR s30.sold_quantity_30d IS NULL)
     AND i.stock > 0
    THEN TRUE
    ELSE FALSE
  END                                                             AS is_toxic,

  -- Стагнация: есть продажи за 30д, но нет за 7д
  CASE
    WHEN COALESCE(s30.sold_quantity_30d, 0) > 0
     AND COALESCE(s7.sold_quantity_7d, 0) = 0
    THEN TRUE
    ELSE FALSE
  END                                                             AS is_stagnant,

  -- is_low_stock: < 7 дней по True ADT 30д (операционный сигнал)
  -- Намеренно оставлен на true_adt — даёт ранний сигнал по быстрым позициям.
  -- Для стратегического анализа используй coverage_days_90d_calendar.
  CASE
    WHEN COALESCE(s30.true_adt, 0) > 0
     AND i.quantity_available > 0
     AND SAFE_DIVIDE(i.quantity_available, s30.true_adt) < 7
    THEN TRUE
    ELSE FALSE
  END                                                             AS is_low_stock,

  -- Излишек: запас > 90 дней по True ADT и есть продажи
  CASE
    WHEN COALESCE(s30.true_adt, 0) > 0
     AND SAFE_DIVIDE(i.quantity_available, s30.true_adt) > 90
    THEN TRUE
    ELSE FALSE
  END                                                             AS is_overstock,

  -- Нулевая себестоимость
  CASE WHEN i.cost_kgs = 0 THEN TRUE ELSE FALSE END               AS is_zero_cost,

  -- ── Метаданные ──────────────────────────────────────────────────────
  fx.rate_kgs_per_usd,
  CURRENT_TIMESTAMP()                                             AS _mart_refreshed_at

FROM latest_snapshot i

LEFT JOIN `msklad-bi-prod.core.dim_products` p
  ON i.product_id = p.product_id

LEFT JOIN sales_30d s30
  ON i.product_id = s30.product_id

LEFT JOIN sales_90d s90
  ON i.product_id = s90.product_id

LEFT JOIN sales_7d s7
  ON i.product_id = s7.product_id

CROSS JOIN latest_fx fx
