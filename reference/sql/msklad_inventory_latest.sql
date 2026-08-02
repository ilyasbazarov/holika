-- FILE: reference/sql/msklad_inventory_latest.sql
-- Снимок Custom Query Looker Studio. Источник: msklad_inventory_latest
-- Снят: 2026-07-30, предоставлен владельцем текстом (ADR-085 §8, задача LS-QUERY-SNAPSHOT)
-- Страница дашборда: Склад (снято владельцем 2026-07-30)
-- Период: отсутствует, берётся последний доступный date_snapshot
-- Правка 2026-08-03 (задача LS-INVENTORY-EXPLICIT-COLUMNS, ADR-087 §7): SELECT * заменён явным
-- списком колонок, снятым с живой схемы `msklad-bi-prod.marts.inventory_health` тем же прогоном
-- (INFORMATION_SCHEMA.COLUMNS, 2026-08-03T18:26:52Z). Список ПОЛНЫЙ — все 32 колонки таблицы на
-- момент съёма, не только используемые графиками страницы «Склад» (ADR-087 §7).

SELECT
  date_snapshot,
  product_id,
  product_name,
  article,
  product_folder,
  entity_type,
  parent_product_id,
  stock,
  reserve,
  quantity_available,
  stock_days,
  cost_kgs,
  frozen_capital_kgs,
  frozen_capital_usd,
  sold_quantity_30d,
  revenue_30d_kgs,
  active_days_30d,
  true_adt,
  calendar_adt,
  sold_quantity_7d,
  sold_quantity_90d,
  calendar_adt_90d,
  coverage_days_true_adt,
  coverage_days_90d_calendar,
  is_oos,
  is_toxic,
  is_stagnant,
  is_low_stock,
  is_overstock,
  is_zero_cost,
  rate_kgs_per_usd,
  _mart_refreshed_at
FROM `msklad-bi-prod.marts.inventory_health`
WHERE date_snapshot = (
  SELECT MAX(date_snapshot) FROM `msklad-bi-prod.marts.inventory_health`
)
