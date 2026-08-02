
-- Правка 2026-08-02, задача LS-RETURNS-FX-HARDCODE (класс A, ADR-087 §5/§6, ADR-062 §2/§5/§6):
-- 1) период переведён на параметры дашборда @DS_START_DATE/@DS_END_DATE (ADR-087 §1/§6), форма —
--    по образцу msklad_expenses.sql/msklad_counterparty_returns.sql;
-- 2) курс 87.4 (литерал) заменён на курс ПО ДАТЕ из core.dim_fx_rates: return_date — дневное зерно
--    строки витрины (группировка идёт по нему), критерий ADR-062 §2 требует курс по дате, не
--    последний курс; COALESCE на последний известный курс — деградация для дат вне покрытия
--    core.dim_fx_rates (граница min_date = 2025-04-29, ADR-062 §6), форма — копия
--    sq_marts_supplier_price_history.sql;
-- 3) поле-обманка устранена: rate_kgs_per_usd теперь несёт независимый от суммы курс дня (после
--    правки 2 тождественность с total_return_sum_usd исчезает по построению).
-- Вставка в интерфейс Looker Studio и read-back — за владельцем (класс B, вне scope этой сессии).

SELECT
  return_date,
  SUM(sum_kgs)                                                    AS total_return_sum_kgs,
  COALESCE(fx.rate_kgs_per_usd,
    (SELECT rate_kgs_per_usd FROM `msklad-bi-prod.core.dim_fx_rates`
     ORDER BY date DESC LIMIT 1))                                 AS rate_kgs_per_usd,
  ROUND(SUM(sum_kgs) / COALESCE(fx.rate_kgs_per_usd,
    (SELECT rate_kgs_per_usd FROM `msklad-bi-prod.core.dim_fx_rates`
     ORDER BY date DESC LIMIT 1)), 2)                              AS total_return_sum_usd,
  COUNT(DISTINCT return_id)                                       AS return_doc_count,
  COUNT(*)                                                        AS return_positions
FROM `msklad-bi-prod.core.fact_returns`
LEFT JOIN `msklad-bi-prod.core.dim_fx_rates` fx
  ON fx.date = return_date
WHERE return_date >= PARSE_DATE('%Y%m%d', @DS_START_DATE)
  AND return_date <= PARSE_DATE('%Y%m%d', @DS_END_DATE)
GROUP BY return_date, fx.rate_kgs_per_usd
