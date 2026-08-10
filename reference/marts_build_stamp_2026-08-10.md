# FILE: marts_build_stamp_2026-08-10.md

# `MARTS-BUILD-STAMP` — форма фикса «маскировки свежести» для пяти таблиц без колонки времени

**Дата:** 2026-08-10 (Бишкек) · **Класс задачи:** A · **Дерево/ветка:** `worktrees/MARTS-BUILD-STAMP` / `s/MARTS-BUILD-STAMP`
**Бриф:** `briefs/MARTS-BUILD-STAMP.md`
**База:** `git rev-parse HEAD` на старте — `73e5bd00c0bf03971363be3d2b903b54c621f307`.

**Постановка (дословно, `07_GAPS.md:67`):** «Пять таблиц не несут отметки времени и методом свежести
не проверяемы; две из них пересобираются ежедневно поверх источников, которые могут стоять, то есть
выглядят свежими независимо от возраста данных — та же маскировка, что два месяца прятала
замороженные счета» (`ADR-111 §4/§6`).

**Почему одной отметки сборки недостаточно (`ADR-111 §6`, своими словами):** витрина, пересобираемая
`CREATE OR REPLACE`/`WRITE_TRUNCATE` каждый день, всегда несёт «свежую» метку момента пересборки —
она обновляется независимо от того, движутся ли данные ИСТОЧНИКА, на которых эта пересборка основана.
Ровно этот механизм два месяца маскировал заморозку `core.fact_customer_invoices` (58 суток без
загрузки, `INVOICES-STALENESS-PROBE`) внутри `marts.customer_invoices_ar`, которая пересобирается
ежедневно поверх него и выглядела бы «свежей» по одной лишь метке сборки. Отсюда требование ДВУХ
раздельных сигналов: (1) когда витрина была пересобрана, (2) насколько свежи данные источника на
момент этой пересборки.

Этот документ — только текстовое предложение (два независимых варианта на таблицу, без выбора одного,
по прецеденту `SALES-REFRESH-WINDOW`, `reference/sales_refresh_window_2026-08-01.md`). Применение,
выбор варианта и деплой — вне scope, класс B/по решению владельца.

---

## Сводная таблица

| Таблица | Форма пересборки (подтверждено чтением) | Источник(и) `core.*` | Статус этой сессии |
|---|---|---|---|
| `core.dim_fx_rates` | не Custom Query — загрузчик `cf-fx` | — | **CONTEXT GAP** — код `cf-fx` не найден в `reference/code/` |
| `marts.customer_invoices_ar` | `WRITE_TRUNCATE` на уровне transferConfig (SQL — чистый `SELECT`, без литерального `CREATE OR REPLACE`) | `core.fact_customer_invoices` | разбор + 2 варианта |
| `marts.expenses` | `WRITE_TRUNCATE` на уровне transferConfig (SQL — чистый `SELECT`, без литерального `CREATE OR REPLACE`) | `core.fact_payments`, `core.fact_loss`, `core.fact_commissionreportin` | разбор + 2 варианта |
| `marts.expenses_staging` | не установлено | — | **CONTEXT GAP** — ни один живой SQ её не строит |
| `marts.weight_flow` | литеральный `CREATE OR REPLACE TABLE … AS` в тексте запроса | `core.fact_sales_profit`, `core.fact_purchases` | разбор + 2 варианта |

Ни один из трёх разобранных запросов не использует `MERGE` — `05_CONVENTIONS.md §C1/§C2` (запрет
`INSERT ROW`, требование ветки удаления) к этим трём **не применим**; подтверждено чтением текста
каждого SQL-снапшота (не предположено).

---

## 1. `core.dim_fx_rates` — CONTEXT GAP

**Расписание (из репо):** ежедневно, `cf-fx` (`11_INFRA_FACTS.md:31-33`) — не Custom Query, загрузчик
Cloud Function.

**Проверка по шагу 2 брифа:** `ls reference/code/` даёт шесть каталогов — `cf-dq`, `cf-facts`,
`cf-finance`, `cf-inventory`, `cf-loss-commission`, `cf-loss-commission.md`. Каталога `cf-fx` среди них
**нет**. `11_INFRA_FACTS.md:33` сам фиксирует это как открытый факт: «Ревизия/URL самой CF `cf-fx`: не
зафиксированы в источнике на момент этой сессии → *(пусто, ожидает discovery)*».

```
CONTEXT GAP: код cf-fx отсутствует в reference/code/ (директории нет), SQL-снапшота у этой таблицы
нет по определению (не Custom Query) — режим записи, условие идемпотентности (MERGE, по 03_PIPELINE_SPEC
§cf-fx: "Идемпотентность: MERGE по дате") и точка вставки колонки возраста источника не проверяемы
чтением кода этой сессией. Поведенческий контракт из 03_PIPELINE_SPEC.md:52-63 (PR-18) документирует
MERGE-идемпотентность и graceful degradation (forward-fill при 401), но это прозаическое описание,
не текст запроса/кода — вставлять колонку в код вслепую запрещено (anti-improvisation). Требуется
discovery: снять исходники cf-fx (по прецеденту SOURCE-MAP-REST/SOURCE-MAP-SALES) прежде чем
проектировать форму правки для этой одной таблицы.
```

Это частичный `CONTEXT GAP` по одной строке — по аналогии с `SALES-MERGE-DRYRUN` (`ADR-097`, где вопрос
(б) остался гэпом, а вопрос (а) был закрыт) остальные четыре таблицы ниже разобраны без блокировки.

---

## 2. `marts.customer_invoices_ar`

**Расписание (из репо):** ежедневно, якорь `10:00 UTC` (`11_INFRA_FACTS.md:113`: `scheduleOptionsV2`,
`nextRunTime 2026-07-28T10:00:00Z`, `updateTime 2026-06-05T10:00:27Z`).

**Форма пересборки (подтверждено чтением):**
- Живой SQL-снапшот `reference/sql/sq_marts_customer_invoices_ar.sql` — чистый агрегирующий `SELECT`
  (строки 2-25), **без литерального `CREATE OR REPLACE`** в тексте запроса.
- Режим записи — на уровне transferConfig, не в тексте SQL: `reference/sql/README.md:31` фиксирует
  «⚠ не задан в transferConfig (см. наблюдения)» для поля `schedule`, а `README.md:48` называет
  фактический механизм — `write_disposition: WRITE_TRUNCATE`. То есть таблица переписывается целиком
  каждый прогон, но НЕ через `CREATE OR REPLACE TABLE` в самом запросе — через конфигурацию
  Data Transfer Service. Формулировка отчёта `core_freshness_sweep_2026-08-02.md:193` («пересобирается
  `CREATE OR REPLACE` ежедневно») описывает НЕТТО-эффект (полная замена), не буквальный SQL-синтаксис —
  уточнено этой сессией.
- Источник: `FROM `msklad-bi-prod.core.fact_customer_invoices` i` (`sq_marts_customer_invoices_ar.sql:19`),
  один источник.
- Колонки момента пересборки или возраста источника в тексте запроса **нет** — подтверждает вердикт
  брифа «не проверяема методом свежести».

**Колонка возраста источника (подтверждено чтением схемы, `core_freshness_sweep_2026-08-02.md:46,91`):**
`core.fact_customer_invoices._loaded_at` (TIMESTAMP) — та самая колонка, замороженная 58 суток
(`2026-06-05T09:06:57Z`), находка `INVOICES-STALENESS-PROBE`.

### Вариант «две колонки»

Вставка — новые элементы `SELECT`-списка, перед `FROM` (`sq_marts_customer_invoices_ar.sql:18→19`):

```sql
SELECT
  i.agent_id,
  i.agent_name,
  COALESCE(c.country, 'Не указана') AS country,
  i.state_name,
  i.state_id,
  COUNT(DISTINCT i.invoice_id)        AS invoice_count,
  ROUND(SUM(i.sum_kgs), 2)            AS total_invoiced_kgs,
  ROUND(SUM(i.payed_sum_kgs), 2)      AS total_paid_kgs,
  ROUND(SUM(i.unpaid_sum_kgs), 2)     AS total_unpaid_kgs,
  MIN(i.moment)                       AS earliest_invoice_date,
  MAX(i.moment)                       AS latest_invoice_date,
  COUNTIF(
    i.payment_planned IS NOT NULL
    AND i.payment_planned < CURRENT_DATE()
    AND i.unpaid_sum_kgs > 0
  )                                   AS overdue_count,
  CURRENT_TIMESTAMP()                 AS _marts_built_at,
  (SELECT MAX(_loaded_at)
     FROM `msklad-bi-prod.core.fact_customer_invoices`) AS _source_max_loaded_at
FROM `msklad-bi-prod.core.fact_customer_invoices` i
...
```

### Вариант «одна производная колонка»

Тот же insert-point, вместо двух колонок — одна:

```sql
  ...
  COUNTIF( ... )                      AS overdue_count,
  TIMESTAMP_DIFF(
    CURRENT_TIMESTAMP(),
    (SELECT MAX(_loaded_at) FROM `msklad-bi-prod.core.fact_customer_invoices`),
    SECOND
  )                                    AS _source_lag_seconds
FROM `msklad-bi-prod.core.fact_customer_invoices` i
...
```

### Сравнение (без ранжирования)

| | «Две колонки» | «Одна производная» |
|---|---|---|
| Что видно потребителю Looker Studio без пересчёта | момент сборки И момент источника раздельно | только итоговый лаг в секундах |
| Реконструируется ли момент источника обратно | да, напрямую (`_source_max_loaded_at`) | только через вычитание из `_marts_built_at`, если он тоже добавлен отдельно |
| Устойчивость к смене часового пояса отчёта | оба поля TIMESTAMP, зона не теряется | секунды не несут зоны, требуют документированной точки отсчёта |
| Порог DQ-проверки свежести (будущая `DQ-FRESHNESS-COVERAGE`) | сравнение `_marts_built_at - _source_max_loaded_at` считается вне SQL, в чеке | порог сравнивается с `_source_lag_seconds` напрямую, без вычитания в чеке |
| Добавляемых колонок в витрину | 2 | 1 |

---

## 3. `marts.expenses`

**Расписание (из репо):** ежедневно, якорь `11:10 UTC` (`11_INFRA_FACTS.md:112`: «прогоны
25/26/27.07.2026, ровно один в сутки», `updateTime 2026-06-05T11:10:23Z`).

**Форма пересборки (подтверждено чтением):**
- Живой SQL-снапшот `reference/sql/sq_marts_expenses.sql` — CTE `src` (строки 1-57) объединяет три
  источника через `UNION ALL`, финальный агрегирующий `SELECT` (строки 58-87). **Без литерального
  `CREATE OR REPLACE`** в тексте запроса.
- Режим записи — как и у `customer_invoices_ar`, на уровне transferConfig: `reference/sql/README.md:30`
  «⚠ не задан в transferConfig», `README.md:48` — `write_disposition: WRITE_TRUNCATE`.
- Источники (подтверждено чтением `src`, строки 14, 31, 55):
  - `FROM `msklad-bi-prod.core.fact_payments` p` (строка 14)
  - `FROM `msklad-bi-prod.core.fact_loss` l` (строка 31)
  - `FROM `msklad-bi-prod.core.fact_commissionreportin` c` (строка 55)
- Колонки момента пересборки или возраста источника в тексте запроса **нет**.

**Колонки возраста источника (подтверждено чтением схемы, `core_freshness_sweep_2026-08-02.md:45,49,53,90,93,98`):**
все три источника несут `_loaded_at` (TIMESTAMP): `core.fact_payments._loaded_at`,
`core.fact_loss._loaded_at`, `core.fact_commissionreportin._loaded_at`.

**Развилка агрегации (открыта, не решена этой сессией):** при трёх источниках «возраст источника»
может быть (a) наименьшим из трёх `MAX(_loaded_at)` — то есть возрастом САМОГО ОТСТАЛОГО источника,
что и обнаруживает маскировку (если хотя бы один источник встал, лаг вырастет), либо (b) тремя
раздельными колонками по источнику. Ниже оба варианта правки используют (a) — `LEAST()` — как
единственное значение на таблицу; выбор (a) vs (b) сам является открытым вопросом, см. §6.

### Вариант «две колонки»

Вставка — новые элементы финального `SELECT`-списка, перед `FROM src s` (`sq_marts_expenses.sql:77→78`):

```sql
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
  ROUND(SUM(s.sum_kgs) / COALESCE(fx.rate_kgs_per_usd,
    (SELECT rate_kgs_per_usd FROM `msklad-bi-prod.core.dim_fx_rates`
     ORDER BY date DESC LIMIT 1)), 2)             AS total_sum_usd,
  CURRENT_TIMESTAMP()                             AS _marts_built_at,
  LEAST(
    (SELECT MAX(_loaded_at) FROM `msklad-bi-prod.core.fact_payments`),
    (SELECT MAX(_loaded_at) FROM `msklad-bi-prod.core.fact_loss`),
    (SELECT MAX(_loaded_at) FROM `msklad-bi-prod.core.fact_commissionreportin`)
  )                                                AS _source_max_loaded_at
FROM src s
...
```

### Вариант «одна производная колонка»

```sql
  ...
  ROUND(SUM(s.sum_kgs) / COALESCE( ... ), 2)      AS total_sum_usd,
  TIMESTAMP_DIFF(
    CURRENT_TIMESTAMP(),
    LEAST(
      (SELECT MAX(_loaded_at) FROM `msklad-bi-prod.core.fact_payments`),
      (SELECT MAX(_loaded_at) FROM `msklad-bi-prod.core.fact_loss`),
      (SELECT MAX(_loaded_at) FROM `msklad-bi-prod.core.fact_commissionreportin`)
    ),
    SECOND
  )                                                AS _source_lag_seconds
FROM src s
...
```

### Сравнение (без ранжирования)

| | «Две колонки» | «Одна производная» |
|---|---|---|
| Видимость отставания КОНКРЕТНОГО источника из трёх | нет (уже свёрнуто `LEAST` в обоих вариантах — это ограничение развилки §6, не варианта) | нет, тот же предел |
| Читается ли DQ-чеком без вычитания в чеке | нет, чек вычитает | да |
| Число новых колонок | 2 | 1 |
| Стоимость трёх коррелированных подзапросов `MAX()` | одинаковая в обоих вариантах — оценка производительности вне scope этой сессии |

---

## 4. `marts.expenses_staging` — CONTEXT GAP

**Расписание (из репо):** не задокументирована; вторичный сигнал хранилища — 5 суток без изменений на
момент замера `CORE-FRESHNESS-SWEEP` (`core_freshness_sweep_2026-08-02.md:199`: `last_modified_time`
`2026-07-28`).

**Проверка по шагу 2 брифа — поиск адреса строящего SQ:**
- `03_PIPELINE_SPEC.md §marts — SQL` (строки 256-287) перечисляет ВСЕ Custom Query, строящие `marts.*`:
  легаси `sq_marts_expenses` → `marts.expenses` и восемь канонических SQ (таблица строк 274-283) →
  `marts.inventory_health`, `marts.sales_overview`, `marts.gmroi_by_folder`, `marts.gmroi`,
  `marts.abc_xyz`, `marts.supplier_price_history`, `marts.weight_flow`, `marts.customer_invoices_ar`.
  `marts.expenses_staging` в этом списке **не названа**.
- `11_INFRA_FACTS.md §SQ` (строки 103-117) — та же таблица Config ID/расписание, тот же состав целевых
  таблиц, тот же результат: `marts.expenses_staging` не адресована ни одним из 13 живых Config ID
  («Инвентарь флота (13 конфигураций)», строка 119).
- `grep -rln "expenses_staging" reference/sql/` — 0 совпадений: ни один файл `reference/sql/*.sql` не
  содержит имени этой таблицы ни как источник, ни как цель.

```
CONTEXT GAP: ни 03_PIPELINE_SPEC.md §marts — SQL, ни 11_INFRA_FACTS.md §SQ, ни каталог
reference/sql/ не называют Custom Query или CF, строящую marts.expenses_staging. Кто её пишет —
не установлено репозиторием (бриф явно запрещает изобретать источник по этой строке). Форма
правки для этой таблицы не проектируется этой сессией; требуется discovery (найти transferConfig
по имени таблицы через bq show/list за пределами репо, либо CF-код, если это не Custom Query).
```

---

## 5. `marts.weight_flow`

**Расписание (из репо):** не задокументирована (Config ID есть в `11_INFRA_FACTS.md §SQ`, поля
`schedule` в выдаче нет — DEFER, вне scope этой сессии); вторичный сигнал хранилища — 12ч на момент
замера (`core_freshness_sweep_2026-08-02.md:200`).

**Форма пересборки (подтверждено чтением):**
- Живой SQL-снапшот `reference/sql/sq_marts_weight_flow.sql` — **литеральный**
  `CREATE OR REPLACE TABLE `msklad-bi-prod.marts.weight_flow` AS` (строка 9), в отличие от двух таблиц
  выше. Две CTE `outbound` (строки 13-29) и `inbound` (строки 31-49), объединённые `UNION ALL`
  (строки 51-53), с финальной сортировкой `ORDER BY flow_date DESC, flow_direction` (строка 54).
- Источники (подтверждено чтением, строки 25, 43):
  - `FROM `msklad-bi-prod.core.fact_sales_profit` f` (строка 25, ветка `outbound`)
  - `FROM `msklad-bi-prod.core.fact_purchases` pu` (строка 43, ветка `inbound`)
- Колонки момента пересборки или возраста источника в тексте запроса **нет**.

**Колонки возраста источника (подтверждено чтением схемы, `core_freshness_sweep_2026-08-02.md:51,90,53,96`):**
`core.fact_sales_profit._loaded_at` (TIMESTAMP), `core.fact_purchases._loaded_at` (TIMESTAMP). Обе —
таблицы, найденные ОТСТАЮЩИМИ этим же замером («18ч 42м»/«18ч 39м, заданий с тех пор нет»,
`core_freshness_sweep_2026-08-02.md:230,228`) — то есть `weight_flow` это ровно случай, названный в
`finish_calibration_2026-08-05.md:254-256` как находка, «ради которой строка заведена»: витрина
«в пути»-класса, пересобираемая раз в сутки поверх ядра, которое на момент замера уже отставало.

**Особенность вставки:** `SELECT * FROM outbound UNION ALL SELECT * FROM inbound ORDER BY …` не имеет
собственного списка колонок — добавление новых полей требует обернуть объединение в дополнительный
слой `SELECT`, а не дописать колонку в конец существующего `SELECT *`. Ниже — текст обеих CTE не
меняется, добавляется третья CTE `combined` и финальный `SELECT`.

### Вариант «две колонки»

```sql
CREATE OR REPLACE TABLE `msklad-bi-prod.marts.weight_flow` AS

WITH

outbound AS (
  SELECT
    f.transaction_date                                    AS flow_date,
    DATE_TRUNC(f.transaction_date, WEEK(SATURDAY))        AS week_start,
    DATE_TRUNC(f.transaction_date, MONTH)                 AS month_start,
    'outbound'                                            AS flow_direction,
    ROUND(SUM(f.sell_quantity * COALESCE(p.weight, 0)), 2) AS weight_kg,
    COUNT(*)                                              AS positions_total,
    COUNTIF(COALESCE(p.weight, 0) > 0)                   AS positions_with_weight,
    ROUND(
      SAFE_DIVIDE(COUNTIF(COALESCE(p.weight, 0) > 0), COUNT(*)) * 100, 1
    )                                                     AS weight_coverage_pct
  FROM `msklad-bi-prod.core.fact_sales_profit` f
  LEFT JOIN `msklad-bi-prod.core.dim_products` p
    ON f.product_id = p.product_id
  GROUP BY f.transaction_date
),

inbound AS (
  -- без изменений, строки 31-49 снапшота
  ...
),

combined AS (
  SELECT * FROM outbound
  UNION ALL
  SELECT * FROM inbound
)

SELECT
  c.*,
  CURRENT_TIMESTAMP() AS _marts_built_at,
  LEAST(
    (SELECT MAX(_loaded_at) FROM `msklad-bi-prod.core.fact_sales_profit`),
    (SELECT MAX(_loaded_at) FROM `msklad-bi-prod.core.fact_purchases`)
  )                    AS _source_max_loaded_at
FROM combined c
ORDER BY c.flow_date DESC, c.flow_direction;
```

### Вариант «одна производная колонка»

Тот же каркас (`combined` CTE без изменений), финальный `SELECT` заменяется на:

```sql
SELECT
  c.*,
  TIMESTAMP_DIFF(
    CURRENT_TIMESTAMP(),
    LEAST(
      (SELECT MAX(_loaded_at) FROM `msklad-bi-prod.core.fact_sales_profit`),
      (SELECT MAX(_loaded_at) FROM `msklad-bi-prod.core.fact_purchases`)
    ),
    SECOND
  ) AS _source_lag_seconds
FROM combined c
ORDER BY c.flow_date DESC, c.flow_direction;
```

### Сравнение (без ранжирования)

| | «Две колонки» | «Одна производная» |
|---|---|---|
| Требует ли структурной правки запроса (обёртка `combined`) | да, в обоих вариантах — свойство исходной формы `SELECT * … UNION ALL`, не варианта |
| Различает ли отставание `fact_sales_profit` от `fact_purchases` | нет (`LEAST`, та же развилка агрегации, что у `expenses`, см. §3) | нет, тот же предел |
| Число новых колонок | 2 | 1 |
| Совместимость со `SELECT *`-потребителями (если такие есть) | новая колонка появится у всех — потребитель, ожидающий фиксированный список полей, увидит лишние; не проверено (см. §6) | то же |

---

## 6. Открытые вопросы — явно НЕ решаются этой сессией

- **Какая колонка станет входом будущей проверки свежести (`DQ-FRESHNESS-COVERAGE`).** Эта задача
  проектирует форму витрины, не форму DQ-чека — та же задача, другая строка реестра, не сливается
  (условие брифа).
- **Ломает ли добавление колонок существующих потребителей Looker Studio.** Состав колонок страниц,
  читающих `customer_invoices_ar`/`expenses`/`weight_flow`, этой сессией не проверялся (вне scope
  брифа явно).
- **Развилка агрегации при нескольких источниках (`LEAST()` единого значения vs раздельные колонки
  по источнику) — открыта для `marts.expenses` (три источника, §3) и `marts.weight_flow` (два
  источника, §5).** Ни один из двух вариантов правки её не решает — оба используют `LEAST()` как
  допущение, не решение; альтернатива (раздельная колонка `_source_max_loaded_at_<источник>` на
  каждый источник) не расписана как отдельный третий вариант — вне объёма «минимум два варианта»,
  но названа как возможность на случай, если `LEAST()` окажется недостаточным для будущего DQ-чека.
- **`MERGE`/C1/C2 (`05_CONVENTIONS.md §C1/§C2`) не применимы** ни к одной из трёх разобранных таблиц —
  подтверждено чтением: все три пишутся `WRITE_TRUNCATE`/`CREATE OR REPLACE`, не `MERGE`. Открытым
  остаётся `core.dim_fx_rates` (см. §1) — по `03_PIPELINE_SPEC.md:57` прозаически описан `MERGE`, но
  код не поднят, применимость C1/C2 не подтверждена чтением.
- **`core.dim_fx_rates` (§1) и `marts.expenses_staging` (§4) — оба CONTEXT GAP**, discovery для
  каждой — отдельная задача (не входит в возврат этой сессии по брифу).

---

## Что НЕ сделано этой сессией (явно)

- Ни один вариант правки не выбран/не отранжирован — по прямому требованию брифа и прецеденту
  `SALES-REFRESH-WINDOW`.
- Ничего не задеплоено, ни один живой `transferConfig`/CF не тронут — задача класса A, только чтение.
- Discovery по `cf-fx` и по адресу `marts.expenses_staging` не произведён — оба зафиксированы как
  `CONTEXT GAP`, не догадка.
- Порог/механизм будущего DQ-чека, читающего эти колонки, не спроектирован (`DQ-FRESHNESS-COVERAGE`).
