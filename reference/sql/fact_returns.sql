-- FILE: reference/sql/fact_returns.sql
-- Снимок Custom Query Looker Studio. Источник: fact_returns
-- Снят: 2026-07-30, предоставлен владельцем текстом (ADR-085 §8, задача LS-QUERY-SNAPSHOT)
-- Страница дашборда: Executive summary (снято владельцем 2026-07-30)
-- Период: скользящее окно 90 дней, параметры дашборда не используются. Дата-контрол на странице
--          ЕСТЬ (автоматический диапазон), то есть блок не отвечает на выбор периода зрителем.
--          Переводится под параметры дашборда (ADR-087 §6, задача LS-RETURNS-FX-HARDCODE)
-- Наблюдение: курс 87.4 вписан литералом; поле rate_kgs_per_usd по формуле тождественно
--             total_return_sum_usd (SUM(x)/87.4 = SUM(x/87.4)), то есть колонка с именем
--             курса несёт сумму (задача LS-RETURNS-FX-HARDCODE)
-- Текст ниже дословный, правки не вносились.

SELECT
  return_date,
  SUM(sum_kgs)                     AS total_return_sum_kgs,
  SUM(sum_kgs) / 87.4              AS rate_kgs_per_usd,
  SUM(sum_kgs / 87.4)              AS total_return_sum_usd,
  COUNT(DISTINCT return_id)        AS return_doc_count,
  COUNT(*)                         AS return_positions
FROM `msklad-bi-prod.core.fact_returns`
WHERE return_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY)
GROUP BY return_date
