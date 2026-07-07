-- =============================================================================
-- marts.sales_overview
-- Scheduled Query: каждые 2 часа (0 */2 * * *)
-- CREATE OR REPLACE TABLE — полная пересборка из core.fact_sales_profit.
--
-- ⚠️  TODO (Неделя 3, День 1): раскомментировать блок fact_returns JOIN
-- после того как будет подтверждена схема core.fact_returns.
-- Сейчас return_sum_kgs / return_quantity = 0 (плейсхолдеры).
-- Трекер: Аппендикс К, секция 9 — "marts.sales_overview: заменить
-- return_sum_kgs на LEFT JOIN core.fact_returns"
-- =============================================================================

CREATE OR REPLACE TABLE `msklad-bi-prod.marts.sales_overview` AS

WITH

-- ── БЛОК ВОЗВРАТОВ ──────────────────────────────────────────────────────
returns_agg AS (
  SELECT
    return_date,
    product_id,
    agent_id,
    SUM(sum_kgs)      AS return_sum_kgs,
    SUM(quantity)     AS return_quantity,
    SUM(CASE WHEN NOT has_basis THEN sum_kgs ELSE 0 END) AS no_basis_sum_kgs,
    COUNT(DISTINCT return_id)                            AS return_doc_count
  FROM `msklad-bi-prod.core.fact_returns`
  GROUP BY return_date, product_id, agent_id
),
-- ─────────────────────────────────────────────────────────────────────────

main AS (
  SELECT
    -- ── Временной срез ──────────────────────────────────────────────────
    f.transaction_date,
    DATE_TRUNC(f.transaction_date, WEEK(SATURDAY)) AS week_start,
    DATE_TRUNC(f.transaction_date, MONTH)           AS month_start,
    FORMAT_DATE('%Y-W%V', f.transaction_date)       AS iso_week_label,

    -- ── Продукт ──────────────────────────────────────────────────────
    f.product_id,
    p.name                                          AS product_name,
    p.article,
    p.product_folder,
    p.entity_type,
    p.parent_product_id,
    p_parent.name                                   AS parent_product_name,

    -- ── Контрагент + менеджер ────────────────────────────────────────
    f.agent_id,
    c.name                                          AS counterparty_name,
    COALESCE(c.country, 'Не указана')               AS country,
    c.owner_employee_id,
    e.full_name                                     AS manager_name,
    e.position                                      AS manager_position,

    -- ── Канал продаж / Проект ────────────────────────────────────────
    COALESCE(f.sales_channel_name, 'Не указан')     AS sales_channel_name,
    COALESCE(f.project_name, 'Не указан')           AS project_name,

    -- ── Продажи (KGS) ──────────────────────────────────────────────
    f.sell_quantity,
    ROUND(f.revenue_kgs, 2)                         AS revenue_kgs,
    ROUND(COALESCE(f.cogs_kgs, 0), 2)               AS cogs_kgs,
    ROUND(COALESCE(f.margin_kgs, 0), 2)             AS margin_kgs,

    CASE
      WHEN COALESCE(f.margin_kgs, 0) < 0 THEN 0
      ELSE ROUND(COALESCE(f.margin_kgs, 0), 2)
    END                                             AS margin_kgs_adjusted,

    ROUND(
      SAFE_DIVIDE(COALESCE(f.margin_kgs, 0), NULLIF(f.revenue_kgs, 0)),
      4
    )                                               AS margin_pct,
    f.discount AS discount_percent,

    -- ── Возвраты ──────────────────────────────────────────────────
    COALESCE(r.return_quantity, 0)                  AS return_quantity,
    COALESCE(r.return_sum_kgs, 0)                   AS return_sum_kgs,
    COALESCE(r.no_basis_sum_kgs, 0)                 AS return_no_basis_sum_kgs,
    COALESCE(r.return_doc_count, 0)                 AS return_doc_count,

    -- ── Нетто (продажи - возвраты) ──────────────────────────────────
    ROUND(f.revenue_kgs - COALESCE(r.return_sum_kgs, 0), 2) AS net_revenue_kgs,
    f.sell_quantity - COALESCE(r.return_quantity, 0)         AS net_quantity,

    -- ── USD ──────────────────────────────────────────────────────
    ROUND(COALESCE(f.revenue_usd, 0), 2)            AS revenue_usd,
    ROUND(COALESCE(f.cogs_usd, 0), 2)               AS cogs_usd,
    ROUND(COALESCE(f.margin_usd, 0), 2)             AS margin_usd,
    ROUND(
      SAFE_DIVIDE(COALESCE(r.return_sum_kgs, 0), NULLIF(fx.rate_kgs_per_usd, 0)),
      2
    )                                               AS return_sum_usd,
    fx.rate_kgs_per_usd,

    -- ── Флаги качества данных ──────────────────────────────────────
    CASE WHEN f.cogs_kgs IS NULL THEN TRUE ELSE FALSE END AS is_cogs_missing,
    CASE WHEN f.agent_id IS NULL THEN TRUE ELSE FALSE END AS is_agent_missing,

    -- ── Метаданные ──────────────────────────────────────────────────
    CURRENT_TIMESTAMP()                             AS _mart_refreshed_at

  FROM `msklad-bi-prod.core.fact_sales_profit` f

  LEFT JOIN `msklad-bi-prod.core.dim_products` p
    ON f.product_id = p.product_id

  LEFT JOIN `msklad-bi-prod.core.dim_products` p_parent
    ON p.parent_product_id = p_parent.product_id

  LEFT JOIN `msklad-bi-prod.core.dim_counterparties` c
    ON f.agent_id = c.agent_id
    AND c.scd2_is_current = TRUE

  LEFT JOIN `msklad-bi-prod.core.dim_employees` e
    ON c.owner_employee_id = e.employee_id

  LEFT JOIN `msklad-bi-prod.core.dim_fx_rates` fx
    ON f.transaction_date = fx.date

  LEFT JOIN returns_agg r
    ON f.transaction_date = r.return_date
    AND f.product_id = r.product_id
    AND COALESCE(f.agent_id, '') = COALESCE(r.agent_id, '')
)

SELECT * FROM main;
