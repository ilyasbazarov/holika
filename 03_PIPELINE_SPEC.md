# 03 · PIPELINE_SPEC — Доменная логика ядра

**Версия:** 0.1 (скелет, M-P3a) · **Статус:** SEMI-STABLE
**Назначение:** доменная логика пайплайна — режимы Cloud Functions, DQ-чеки/пороги, семантика загрузок (MERGE/DELETE, Ghost Records), логика мартов, ABC/XYZ, инварианты данных.
Секции — скелет: заголовок + указатель трассировки. Прод-наполнение прозой — P4.

---

## §режимы cf-facts

**Режимы (mode), CF `cf-facts`** (PR-09):

| mode | window_days | Что делает |
|---|---|---|
| hourly | 7 (default) | Загружает staging из МойСклад за последние 7 дней |
| promote | 7 или 90 | MERGE staging → `core.fact_sales_profit`, без DQ check |
| weekly | 90 | Полный reload 90 дней (для FIFO-пересчёта после поставок) |
| returns | 730 | TRUNCATE + reload `fact_returns` за 2 года |
| purchases | 90 | MERGE `fact_purchases` за 90 дней |

**Константы/окна (PR-17):**
```python
HOURLY_WINDOW_DAYS  = 7
WEEKLY_WINDOW_DAYS  = 90
STG_FACT_SALES      = "msklad-bi-prod.stg_msklad.fact_sales_staging"
CORE_FACT_SALES     = "msklad-bi-prod.core.fact_sales_profit"
CORE_BYVARIANT_BCK  = "msklad-bi-prod.core.fact_sales_profit_byvariant_backup"
CORE_FACT_PURCHASES = "msklad-bi-prod.core.fact_purchases"
IN_TRANSIT_STATUS_ID = "491d6da5-8b37-11ef-0a80-0762000253a8"  # "В пути"
```
UUID статусов заказа поставщику (`PURCHASE_ORDER_STATES`) — DROP-DUP, см. `02_ERP_CONTRACTS` §справочные данные (единая точка, PR-28 §6).

*(PR-09, PR-17)*

## §cf-finance

**Канонический порядок `run_etl()`** (PR-14, подтверждено логами 2026-06-25):
1. Полная выгрузка `paymentout`+`cashout` из МойСклада (без date-фильтра).
2. `Loading N records to STG...` — `WRITE_TRUNCATE` в `fact_payments_stg`.
3. `Running MERGE...` — `MERGE` staging → `core.fact_payments` по `payment_id`.
4. `Cleaning up excluded system expenses (ghosts removal)...` — `DELETE` по `EXCLUDE_EXPENSE_IDS`.
5. `Triggering scheduled query via API...` — `trigger_marts()`, может упасть (шаги 1–4 уже закоммичены к этому моменту, падение шага 5 их не откатывает).

**Поведенческие факты (PR-13, PR-35 правило 41):**
- `run_etl()` при КАЖДОМ запуске делает полный re-fetch всей истории `paymentout`+`cashout`, без инкрементального окна (в отличие от `cf-facts`, где есть `window_days`). Надёжно при малом объёме, но линейно растёт по времени и риску таймаута.
- После `MERGE`+`DELETE` вызывается `trigger_marts()` — форс-триггер `sq_marts_expenses` через BigQuery Data Transfer API; `etl-sa` не имеет прав на это (`PermissionDenied`). Вызов обёрнут в `try/except` — падение не блокирует ответ функции, но форс-триггер никогда не срабатывает; `sq_marts_expenses` обновляется по собственному расписанию независимо.

Конфиг/ревизии/Scheduler cf-finance → `11_INFRA_FACTS` §CF (см. патч этой сессии).

*(PR-14, PR-13, PR-35 правило 41)*

## §cf-fx

**Топология/поведение (PR-18, после миграции 2026-06-03):**
- Источник: Bakai Bank OpenBanking API → `officialRates[USD].rate` (курс НБКР).
- Auth: JWT-токен, Bearer, из Secret Manager.
- Идемпотентность: `MERGE` по дате — дублей нет.
- Graceful degradation: при 401 от Bakai → forward-fill последнего известного курса + лог `"update bakai-fx-token in Secret Manager"`.
- Архив: снапшот курса сохраняется в GCS по шаблону `fx-rates/bakai_{YYYY-MM-DD}.json`.

URL/секрет (имя) → `11_INFRA_FACTS` §CF/§секреты (см. патч этой сессии). TTL JWT-токена Bakai не зафиксирован в источнике → **GAP Q-7** (не входит в прозу спеки; рабочая DEFER-политика — ротация по факту 401, `10_OPS_PLAYBOOK` §17).

*(PR-18)*

## §DQ — чеки и пороги

**DQ Gate — 6 чеков (PR-31 + PR-19), CF `cf-dq`:**

| Чек | Порог | Механизм + scope | Что проверяет |
|---|---|---|---|
| not_empty | `staging_count > 0` | cf-dq / DQ Gate, автомат, блокирующий | Staging не пустой |
| drift_check | будни ≥0.10, выходные ≥0.03 | cf-dq / DQ Gate, автомат, блокирующий; **T-1 rev / MA7(T-8…T-2)**, не T-0 (правило 25) | Отклонение выручки от скользящей средней |
| fk_integrity | `orphan_product_ids = 0` | cf-dq / DQ Gate, автомат, блокирующий | Все `product_id` из staging есть в `dim_products` |
| freshness | `lag_days ≤ 3` | cf-dq / DQ Gate, автомат, блокирующий, на `MAX(DATE(transaction_date_raw))` | Устаревание бизнес-данных в CORE |
| margin_sanity | `bad_margin_rows = 0` | cf-dq / DQ Gate, автомат, блокирующий | Строки с маржой > 100% выручки |
| currency_normalization | `avg_revenue_kgs < 10M` | cf-dq / DQ Gate, автомат, блокирующий | Данные в KGS, не в тыйынах |

**Стандарт T-1 (PR-34 правило 25):** `drift_check` сравнивает выручку **вчера (T-1)** с MA7 за период T-8…T-2 из CORE_FACT. T-0 (текущий день) использовать запрещено — неполный день даёт ложные срабатывания.

**Три порога «свежести» — НЕ примиряются в одно число (ADR-007, accepted):** каждый принадлежит независимому механизму и частично меряет разные колонки.

| Порог | Механизм | Метрика (колонка) + scope | Назначение | При нарушении |
|---|---|---|---|---|
| ≤ 3 дня | cf-dq / DQ Gate (автомат, блокирующий) | `MAX(DATE(transaction_date_raw))`, бизнес-дата | Устаревание бизнес-данных в CORE; терпит пустые дни | DQ FAILED → блок promote; пустой день → manual promote |
| ≤ 6 часов | cf-alert / Telegram (автомат, уведомляющий) | `MAX(transaction_date)`, бизнес-дата | Оперативное уведомление о разрыве потока в течение дня | Telegram-алерт |
| ≤ 2 часа | ручная / runbook (человек, liveness) | `_loaded_at`, техническая дата загрузки | Heartbeat: запускался ли workflow (часовой пайплайн) | Диагностика, `10_OPS_PLAYBOOK` |

Ревизия `cf-dq` после T-1-фикса не подтверждена в источнике → **GAP Q-6** (не гейтит эту таблицу; факт дома в `11_INFRA_FACTS`).

*(PR-31, PR-19, PR-34 правило 25, ADR-007)*

## §marts — логика мартов и ABC/XYZ

**marts.sales_overview** (расписание: каждые 2 часа, CREATE OR REPLACE):
- `country` — `COALESCE(c.country, 'Не указана')` из `dim_counterparties`.
- `manager_name`, `manager_position` — из `dim_employees`.
- `sales_channel_name` — `COALESCE(f.sales_channel_name, 'Не указан')`.
- `project_name` — `COALESCE(f.project_name, 'Не указан')`.
- `return_sum_kgs`, `net_revenue_kgs` — из `LEFT JOIN fact_returns`.
- `is_cogs_missing`, `is_agent_missing` — флаги DQ.

**marts.inventory_health:**

| Поле | Описание |
|---|---|
| coverage_days_90d_calendar | Покрытие в днях (calendar ADT — для B2B) |
| coverage_days_true_adt | Покрытие в днях (true ADT — операционный) |
| is_low_stock, is_oos, is_toxic | Флаги состояния |

**marts.in_transit** (обновлено 2026-06-24 — добавлен `order_name`):

| Поле | Описание |
|---|---|
| order_name | Человекочитаемый номер заказа — основной Dimension в LS (заменяет `purchase_order_id` на дашборде) |
| purchase_order_id | ID заказа поставщику (technical key, не для вывода в LS) |
| position_id | ID позиции заказа |
| days_until_delivery | Отрицательное = просрочено |
| is_overdue | `planned < TODAY AND planned IS NOT NULL` |
| product_name, product_folder | Денормализовано из `dim_products` |
| supplier_name | Денормализовано из `dim_counterparties` (`JOIN AND scd2_is_current = TRUE`) |
| status_name | Статус заказа |
| quantity_ordered, quantity_shipped, quantity_in_transit | Количества |
| in_transit_sum_kgs, in_transit_sum_usd | Суммы в пути |
| fx_rate_used | Курс FX, использованный при конвертации |

**Канонический SQL `in_transit`** (актуальный, 2026-06-24; SQ Config ID `6a0aa537-0000-260f-b391-d43a2cee6b87`, патч только через `bq update --transfer_config` Python, не heredoc):
```sql
CREATE OR REPLACE TABLE `msklad-bi-prod.marts.in_transit`
CLUSTER BY supplier_id, product_id
AS
WITH latest_fx AS (
  SELECT rate_kgs_per_usd
  FROM `msklad-bi-prod.core.dim_fx_rates`
  ORDER BY date DESC
  LIMIT 1
)
SELECT
  p.order_name, /* Основное поле для вывода в BI */
  p.purchase_order_id,
  p.position_id,
  p.order_date,
  p.planned_delivery_date,
  CASE
    WHEN p.planned_delivery_date IS NULL THEN NULL
    ELSE DATE_DIFF(p.planned_delivery_date, CURRENT_DATE(), DAY)
  END AS days_until_delivery,
  CASE
    WHEN p.planned_delivery_date IS NOT NULL
     AND p.planned_delivery_date < CURRENT_DATE() THEN TRUE
    ELSE FALSE
  END AS is_overdue,
  p.product_id,
  prod.name AS product_name,
  prod.product_folder AS product_folder,
  p.supplier_id,
  sup.name AS supplier_name,
  p.status_name,
  p.quantity_ordered,
  p.quantity_shipped,
  p.quantity_in_transit,
  p.price_kgs,
  p.in_transit_sum_kgs,
  ROUND(p.in_transit_sum_kgs / fx.rate_kgs_per_usd, 2) AS in_transit_sum_usd,
  fx.rate_kgs_per_usd AS fx_rate_used,
  CURRENT_TIMESTAMP() AS _mart_refreshed_at
FROM `msklad-bi-prod.core.fact_purchases` p
CROSS JOIN latest_fx fx
LEFT JOIN `msklad-bi-prod.core.dim_products` prod
  ON p.product_id = prod.product_id
LEFT JOIN `msklad-bi-prod.core.dim_counterparties` sup
  ON p.supplier_id = sup.agent_id
  AND sup.scd2_is_current = TRUE
WHERE p.status_name IN ('В пути', 'Прибыл частично')
  AND p.in_transit_sum_kgs > 0;
```

**marts.supplier_price_history:**

| Поле | Описание |
|---|---|
| price_kgs, price_usd | Закупочная цена в KGS и USD |
| supplier_name, product_folder | Денормализовано |

**marts.weight_flow** (SQ `6a1f9418-0000-276f-a1e4-d4f547ee7418`):

| Колонка | Тип | Описание |
|---|---|---|
| flow_date | DATE | Дата операции |
| week_start | DATE | Начало недели (WEEK SATURDAY) |
| month_start | DATE | Начало месяца |
| flow_direction | STRING | 'inbound' (приём) / 'outbound' (отгрузка) |
| weight_kg | FLOAT64 | Суммарный вес в кг |
| positions_total | INT64 | Всего позиций |
| positions_with_weight | INT64 | Позиций с `weight > 0` в `dim_products` |
| weight_coverage_pct | FLOAT64 | % позиций с заполненным весом |

**marts.customer_invoices_ar** (SQ `6a23f3ea-0000-2952-853d-582429be7ecc`, ежедневно, CREATE OR REPLACE):

| Колонка | Тип | Описание |
|---|---|---|
| agent_id | STRING | UUID покупателя |
| agent_name | STRING | Имя покупателя |
| country | STRING | Страна (из `dim_counterparties`) |
| state_name | STRING | Статус оплаты |
| state_id | STRING | UUID статуса |
| invoice_count | INT64 | Количество счетов |
| total_invoiced_kgs | FLOAT64 | Выставлено всего, KGS |
| total_paid_kgs | FLOAT64 | Оплачено, KGS |
| total_unpaid_kgs | FLOAT64 | Не оплачено, KGS |
| earliest_invoice_date | DATE | Дата самого раннего счёта |
| latest_invoice_date | DATE | Дата последнего счёта |
| overdue_count | INT64 | Счетов с просроченной плановой датой оплаты |

Назначение: дебиторская задолженность (AR), страница «Операционка». LS источник: `msklad_customer_invoices_ar` (Custom Query, без date range — snapshot).

**ABC/XYZ (marts.abc_xyz):**

| Колонка | Тип | Описание |
|---|---|---|
| abc_class | STRING | A≤80%, B≤95%, C>95% кумулятивной выручки |
| xyz_class | STRING | X≤0.5, Y≤1.0, Z>1.0 CoV |
| abc_xyz | STRING | Конкатенация: AX, AY, BX... |

Распределение X/Y/Z и A-класс SKU — волатильные цифры, дом `07_STATE` §контрольные цифры (уже там: X=39, Y=148, Z=439).

Прочие 10 SQ-мартов (canonical/legacy) → §marts — SQL (ниже, 03e2).

*(PR-29, PR-30)*

## §marts — SQL (легаси и канонический, 03e2)

### Легаси-март расходов (AS-IS/LEGACY)

`sq_marts_expenses` (Config ID `6a22a243-0000-20fd-a458-883d24f4cad4`) — живой SQL на момент выгрузки 2026-07-07, читает `core.fact_payments` (payment-based, только 2 из 4 источников ADR-006: `paymentout`+`cashout`). Документированный оракул-разрыв ~33% (ADR-005 §4). **Статус: LEGACY, вытесняется** TO-BE-мартом ADR-006/§marts.expenses (см. выше); ретайрится в Epic-1 (ADR-009).

Полный SQL — см. `/reference/sql/sq_marts_expenses.sql` (дословный снапшот, не воспроизводится второй раз в спеке).

**Кросс-ссылка (TO-BE):** методология построения марта расходов, которая должна заменить эту легаси-логику — `§marts.expenses` выше (ADR-006, двухисточниковая агрегация `paymentout+cashout+loss` + `entity/commissionreportin`).

*(PR-236, ADR-009)*

### Канонический SQL — оставшиеся 8 март-SQ (Q-5 CLOSED, из `/reference/sql/`)

`in_transit` уже документирован выше (03e1); `sq_marts_expenses` — легаси-раздел выше. 3 audit-SQ — НЕ сюда, дом `11 §SQ` (M-P4-11a, уже сделано).

Дословный SQL каждого — в `/reference/sql/<displayName>.sql` (не дублируется построчно в спеке):

| Config ID | displayName | Файл |
|---|---|---|
| `69fd92d9-0000-2372-ad37-582429aca3ec` | `sq_marts_inventory_health` | `reference/sql/sq_marts_inventory_health.sql` |
| `69ff34b4-0000-2b2b-a390-14c14ef7af10` | `sq_marts_sales_overview` | `reference/sql/sq_marts_sales_overview.sql` |
| `6a004e88-0000-2e7d-bf20-9898fbb40f95` | `sq_marts_gmroi_by_folder` | `reference/sql/sq_marts_gmroi_by_folder.sql` |
| `6a006664-0000-2739-86f5-7474463a7ac5` | `sq_marts_gmroi` | `reference/sql/sq_marts_gmroi.sql` |
| `6a020b2c-0000-2dd6-96d2-883d24f52bd4` | `sq_marts_abc_xyz` | `reference/sql/sq_marts_abc_xyz.sql` |
| `6a0b0f25-0000-2893-be44-d43a2cc31f97` | `sq_marts_supplier_price_history` | `reference/sql/sq_marts_supplier_price_history.sql` |
| `6a1f9418-0000-276f-a1e4-d4f547ee7418` | `sq_marts_weight_flow` | `reference/sql/sq_marts_weight_flow.sql` |
| `6a23f3ea-0000-2952-853d-582429be7ecc` | `sq_marts_customer_invoices_ar` | `reference/sql/sq_marts_customer_invoices_ar.sql` |

**Наблюдение из `reference/sql/README.md`, переносимое как факт (не решение):** `sq_marts_gmroi_by_folder` строится агрегацией поверх `marts.gmroi` (`FROM msklad-bi-prod.marts.gmroi GROUP BY period_days, product_folder`) — SQ-к-SQ зависимость, не прямое чтение core/raw.

*(PR-29 §адрес, Q-5 CLOSED → M-P4-D5 discovery)*

## §marts.expenses — логика марта расходов

**ADR-006 (M-P3c, 2026-07-06): Построение марта расходов дашборда**

**Входные источники:**
- `raw.moysklad_paymentout` (исходящие платежи, с FX по rate.value документа)
- `raw.moysklad_cashout` (выплаты наличностью, с FX по rate.value документа)
- `raw.moysklad_loss` (прямые потери/написания, с FX по rate.value документа)
- `raw.moysklad_commissionreportin` (таблица вознаграждений, reward + commissionOverhead.sum)

**Логика агрегации:**
- Источник #1 (paymentout+cashout+loss): 25 операционные статьи + 1 (Расходы маркетплейсов) с FX-конвертацией по курсу документа.
- Источник #2 (entity/commissionreportin): объединена в категорию «Расходы маркетплейсов» (формула = Σ(reward÷100) + Σ(commissionOverhead.sum÷100)).
- На дашборде: категория «Расходы маркетплейсов» объединяет обе статьи (ADR-006).

**Целевые категории дашборда (26 шт, от заказчика):**

| # | Категория | Источник | Статус |
|---|---|---|---|
| 1 | Налоги и сборы | paymentout+cashout+loss | active |
| 2 | Списания | paymentout+cashout+loss | active |
| 3 | IT | paymentout+cashout+loss | active (нулевое в мае-2026) |
| 4 | Аренда | paymentout+cashout+loss | active (нулевое в мае-2026) |
| 5 | Банк-комиссия | paymentout+cashout+loss | active |
| 6 | Бонусы | paymentout+cashout+loss | active |
| 7 | Бухгалтерские услуги | paymentout+cashout+loss | active |
| 8 | Вывод прибыли | paymentout+cashout+loss | active |
| 9 | Зарплата | paymentout+cashout+loss | active |
| 10 | Интернет и связь | paymentout+cashout+loss | active |
| 11 | Коммунальные услуги | paymentout+cashout+loss | active |
| 12 | Логистика | paymentout+cashout+loss | active |
| 13 | Маркетинг и реклама | paymentout+cashout+loss | active |
| 14 | Мой склад | paymentout+cashout+loss | active |
| 15 | неразнесенные списания | paymentout+cashout+loss | active |
| 16 | нотариальные и юр услуги | paymentout+cashout+loss | active |
| 17 | Обучение | paymentout+cashout+loss | active |
| 18 | Офисные расходы | paymentout+cashout+loss | active |
| 19 | Охрана | paymentout+cashout+loss | active |
| 20 | Покупка основных средств | paymentout+cashout+loss | active |
| 21 | Прочие расходы | paymentout+cashout+loss | active |
| 22 | Расходы маркетплейсов | paymentout+cashout+loss + commissionreportin | active (объединённая) |
| 23 | Ремонт оборудования | paymentout+cashout+loss | active |
| 24 | Тамож расходы | paymentout+cashout+loss | active |
| 25 | Техника | paymentout+cashout+loss | active |
| 26 | Топливо | paymentout+cashout+loss | active |
| 27 | Фулфилмент | paymentout+cashout+loss | active (нулевое в мае-2026) |

**Исключения (не операционные расходы, не включаются в дашборд):**
- Перемещение исходящий
- Благотворительность
- Возврат займа собственнику
- Выплата тела кредита
- Проценты по кредиту
- Возврат

**Ожидаемые нулевые значения в мае-2026 (подтверждены эталоном 2026-07-06):**
- IT
- Аренда
- Фулфилмент

**Выходная таблица:** `marts.expenses` (или аналог)
- Dimensions: 26 категорий дашборда (см. таб. выше), период, валюта
- Facts: сумма по категории и периоду
- Гранулярность: месячная агрегация (или указать в спеке)

<!-- P4: SQL логика построения марта + примеры запросов по периодам. -->

## §fact_payments — семантика загрузки (Ghost Records)

**Фильтрация при загрузке (PR-27, исправлено 2026-06-18 — Ghost Records fix):**
- ✅ `applicable=False` (черновики) — фильтруются на уровне Python при выгрузке. Легитимный фильтр, к Ghost Records не относится.
- ❌ **Статьи-перемещения через `EXCLUDE_EXPENSE_IDS` на уровне Python — БОЛЬШЕ НЕ ИСПОЛЬЗУЕТСЯ.** Старый подход вызывал Ghost Records: если документ изначально был без статьи («Неразнесённое списание»), попадал в BQ; когда клиент позже проставлял статью-исключение (например «Перемещение»), скрипт переставал его выгружать — `MERGE` не видел обновления, и Ghost-запись со старым статусом зависала навсегда.
- ✅ **Новый подход (PR-34 правило 26):** выгружаются ВСЕ платежи без исключений по статье. Системные статьи вычищаются `DELETE` в BigQuery **после** `MERGE`:
```sql
DELETE FROM `msklad-bi-prod.core.fact_payments`
WHERE expense_item_id IN ('24c0e914-2d8c-11f1-0a80-11b0000c7043', ...)
-- полный список — EXCLUDE_EXPENSE_IDS в коде cf-finance, канон в невыгруженном коде (GAP Q-10)
```

Правило на будущее: фильтрация статей расходов ТОЛЬКО через `DELETE` после `MERGE`, никогда через `if/continue` на этапе выгрузки — иначе Ghost Record.

Счётчики записей (волатильные) → `07_STATE` §контрольные цифры (см. STATE_PATCH этой сессии). Полный список `EXCLUDE_EXPENSE_IDS` — вне scope, **GAP Q-10** (канон в коде, закрывается вместе с Q-3). Формализовано как **ADR-011** (`06_DECISIONS_LOG.md`, статус: proposed) — канон: только `DELETE`-after-`MERGE`, `if/continue` на выгрузке запрещён.

*(PR-27, PR-34 правило 26)*

## §операционные инварианты

**Manual promote (PR-33 правила 18–20):**
- FX forward-fill теперь делает `cf-fx` автоматически при 401 от Bakai. Ручной forward-fill нужен только если `cf-fx` сам упал (правило 18).
- **Условие допустимости manual promote (без DQ):** staging > 1000 строк И > 50M KGS за 90 дней (правило 19).
- После manual promote — обязательно запустить `mode=returns, window_days=90` (правило 20).

*(PR-33 правила 18–20)*

## §инварианты данных

- **FIFO пересчитывается при новых поставках (RB-20).** Дрейф исторических данных за последние 90 дней — нормальное поведение, не баг: данные уточняются еженедельно по мере поступления новых партий.
- **Вес позиции > 50 кг для единицы товара — вероятно ошибка ввода (RB-30).** Обычно означает, что в МойСкладе вписан вес коробки/паллеты вместо веса единицы товара; требует сообщения заказчику для исправления, не автоматической коррекции.
- **SCD2 на `dim_counterparties.owner_employee` (RB-22).** Изменение менеджера контрагента отрабатывает автоматически при следующем прогоне CF-Dim — создаётся вторая запись (историчность), а не перезапись текущей. Дополняет общую семантику SCD2-справочников.

*(RB-20, RB-30, RB-22)*

## §конвертация валют (доменная логика)

**Различение входящей и исходящей конвертации (RB-38 п.26.6) — два разных смысла слова «rate» в одной кодовой базе:**
- **Входящая конвертация** — цена/сумма в позиции документа МойСклад изначально в валюте ДОКУМЕНТА (не всегда KGS); требует перевода в KGS ДО расчёта `revenue_kgs`/`sum_kgs` (через `document.rate.value`). Это контрактный факт минорных единиц валюты документа — канон в `02_ERP_CONTRACTS` §валюты (forward-ref, приземляется в брифе A-09/02f).
- **Исходящая конвертация** — уже готовая ИТОГОВАЯ сумма в KGS конвертируется в USD для инвестора/дашборда через `cf-fx`/`dim_fx_rates`. Это отдельная, независимо работающая задача.

Термины (входящая/исходящая конвертация) как единицы словаря — → `09_GLOSSARY` (forward-ref, вне scope этого брифа).

*(RB-38 п.26.6)*
