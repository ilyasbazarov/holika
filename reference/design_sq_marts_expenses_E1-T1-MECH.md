# /reference/design_sq_marts_expenses_E1-T1-MECH.md — Дизайн-скетч (НЕ исполнять)

**Задача:** E1-T1 Шаг 5. **Статус:** design-only, staging-first — прод `transferConfig` (`6a22a243-0000-20fd-a458-883d24f4cad4`, ежедневный деструктивный `WRITE_TRUNCATE`) НЕ трогается ни в каком виде в рамках этой сессии.
**Гейт-факт (Q-31, закрыт 2026-07-21):** `raw.moysklad_loss`/`raw.moysklad_commissionreportin` НЕ существуют как BQ-таблицы (проверено по всем 4 реальным датасетам проекта — `audit`/`core`/`marts`/`stg_msklad`). Дизайн ниже включает **прерогативу ингеста** — это расширяет заявленный в брифе scope «SQL-дельты» до «ингест + SQL-дельта»; фиксирую явно, не подменяю тихо.

---

## Часть A — Новый независимый ингест (прерогатива, вне cf-finance)

**Почему независимый, не расширение cf-finance:** `03 §cf-finance` — код в отдельном репо, не поднятом (`ADR-017 §5`); наследование `ADR-016`-бага нежелательно; развязка cutover от `E1-T3-MECH-FX` (см. вердикт Q-31 выше).

**Предлагаемые новые таблицы (schema — PROPOSED, не факт, требует подтверждения архитектором/владельцем):**
- `core.fact_loss` — по аналогии с `core.fact_payments` (staging `core.fact_loss_stg` → `MERGE`): `document_id`, `moment`, `expense_item_id`, `expense_item_name`, `agent_id`, `agent_name`, `project_id`, `sales_channel_id`, `sum_kgs` (= `minor_units ÷ 100 × rate.value`, ADR-010, корректно с первого дня), `currency_code`, `_loaded_at`.
- `core.fact_commissionreportin` — по мотивам `entity/commissionreportin` (`02_ERP_CONTRACTS §Источник #2`): `document_id`, `moment`, `reward_sum_kgs` (`reward÷100 × rate`), `commission_overhead_sum_kgs` (`commissionOverhead.sum÷100 × rate`), `agent_id`, `_loaded_at`. Категория фиксирована — вся сумма идёт в «Расходы маркетплейсов» (ADR-006 §2), `expense_item_name` не нужен на уровне источника.

**Ингест-механизм:** новая CF (условное имя `cf-finance-ext`, отдельная от `cf-finance` codebase) ИЛИ отдельный скрипт с тем же паттерном `staging→MERGE`, что и `cf-finance`/`cf-facts` (`03_PIPELINE_SPEC`). Провенанс кода — снапшот по `ADR-017 §2/§6` (прецедент распространяется на любую новую CF), не ретро.

**Вне scope дизайна этой сессии:** конкретная реализация CF (код) — не пишется здесь (docs-репо не пишет прод-код, `_METHOD §10`). Это отдельная задача, гейтящая cutover E1-T1-MECH; предлагаю имя `E1-T1-MECH-INGEST` как под-задачу (proposed, для `04_ROADMAP`).

---

## Часть B — SQL-дельта к `sq_marts_expenses` (после появления Части A в БД)

Псевдокод-скелет (полей `core.fact_loss`/`core.fact_commissionreportin` пока нет в БД — точный SQL зависит от финальной schema Части A, здесь — форма и логика, не готовый к запуску текст):

```sql
-- ФОРМА (не готовый SQL — зависит от финальной schema core.fact_loss/core.fact_commissionreportin)
WITH base AS (
  -- существующая логика live SQL (paymentout+cashout via core.fact_payments) — БЕЗ ИЗМЕНЕНИЙ,
  -- всё ещё несёт баг ADR-016 до E1-T3-MECH-FX (смешанное состояние, см. вердикт Q-31)
  SELECT p.moment, p.expense_item_name, p.sum_kgs, 'paymentout_cashout' AS src
  FROM `msklad-bi-prod.core.fact_payments` p
  WHERE p.moment IS NOT NULL
),
loss AS (
  SELECT l.moment, l.expense_item_name, l.sum_kgs, 'loss' AS src
  FROM `msklad-bi-prod.core.fact_loss` l          -- НОВАЯ таблица, Часть A
),
commission AS (
  SELECT c.moment,
         'Расходы маркетплейсов' AS expense_item_name,   -- ADR-006 §2: жёсткая категория, не из источника
         c.reward_sum_kgs + c.commission_overhead_sum_kgs AS sum_kgs,
         'commissionreportin' AS src
  FROM `msklad-bi-prod.core.fact_commissionreportin` c   -- НОВАЯ таблица, Часть A
)
SELECT
  -- нормализация имени под 27-статейный список клиента (ADR-006, case-critical):
  -- канонизировать через LOWER(TRIM(expense_item_name)) + мэппинг-таблицу (НЕ case-sensitive напрямую —
  -- закрывает NAME_CASE-риски из recon_expenses_2026-05.md: Топливо/ТОпливо, Мой Склад/Мой склад,
  -- Банк (комиссия)/Банк-комиссия, Неразнесенное списание/неразнесенные списания)
  expense_item_name,
  DATE_TRUNC(moment, MONTH) AS month_start,
  ROUND(SUM(sum_kgs), 2)    AS total_sum_kgs,
  COUNT(*)                  AS payment_count
FROM (
  SELECT * FROM base
  UNION ALL SELECT * FROM loss
  UNION ALL SELECT * FROM commission
)
GROUP BY expense_item_name, month_start
```

**Обязательные элементы дизайна:**
1. **Staging-first (ADR-012/E1-T1-MECH требование):** материализовать как `marts.expenses_staging_<date>` или отдельный `bq query --destination_table`, НЕ трогая `sq_marts_expenses`/`transferConfig 6a22a243-…` in-place.
2. **Сверка со staging против `pnl_2026-05.md`** — по той же методологии `recon_expenses_2026-05.md`, до апрува cutover.
3. **Раскрытие смешанного состояния** (см. вердикт Q-31) — на самом cutover, не здесь: `base`-часть (paymentout/cashout) остаётся под `ADR-016` до `E1-T3-MECH-FX`; только `loss`/`commission`-часть корректна сразу.
4. **Регистр/формат имён** — нормализация ОБЯЗАТЕЛЬНА при JOIN/фильтрации против 27-статейного списка; список известных вариантов — в `recon_expenses_2026-05.md` (NAME_CASE-заметки).

---

## Статус
`design-only`, не исполнялся. Требует: (а) апрув владельца/архитектора на Часть A (новая CF/схема — новая работа, не в исходном scope брифа как «просто SQL»); (б) финализацию schema `core.fact_loss`/`core.fact_commissionreportin` прежде чем SQL из Части B станет исполняемым.
