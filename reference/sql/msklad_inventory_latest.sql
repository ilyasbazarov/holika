-- FILE: reference/sql/msklad_inventory_latest.sql
-- Снимок Custom Query Looker Studio. Источник: msklad_inventory_latest
-- Снят: 2026-07-30, предоставлен владельцем текстом (ADR-085 §8, задача LS-QUERY-SNAPSHOT)
-- Страница дашборда: Склад (снято владельцем 2026-07-30)
-- Период: отсутствует, берётся последний доступный date_snapshot
-- Наблюдение: SELECT * — любая новая колонка в marts.inventory_health попадает
--             на клиентскую поверхность без решения (Q-87)
-- Текст ниже дословный, правки не вносились.

SELECT * FROM `msklad-bi-prod.marts.inventory_health`
WHERE date_snapshot = (
  SELECT MAX(date_snapshot) FROM `msklad-bi-prod.marts.inventory_health`
)
