# FILE: reference/dq_freshness_coverage_2026-08-09.md

# `DQ-FRESHNESS-COVERAGE` — проверки свежести для шести фактовых таблиц без наблюдателя

**Дата:** 2026-08-09 (Бишкек) · **Класс задачи:** A (подготовка) · **Роль:** исполнитель
**Дерево/ветка:** `worktrees/DQ-FRESHNESS-COVERAGE` / `s/DQ-FRESHNESS-COVERAGE`
**Бриф:** `briefs/DQ-FRESHNESS-COVERAGE.md`
**Скрипты и провенанс:** `reference/_scratch_DQ-FRESHNESS-COVERAGE_2026-08-09/dry_run_freshness_checks.sh`
+ `.../dry_run_freshness_checks.log` (не убирается, `ADR-043`; путь провенанса — здесь)

**Назначение файла.** Самодостаточный артефакт: по каждой из шести таблиц — источник каденции,
вывод порога (A), текст обеих проверок, результат `dry_run`, статус инварианта «один стамп
`_loaded_at` на прогон». Код лежит в `reference/code/cf-dq/main.py` (функции) +
`reference/code/cf-dq/config.py` (пороги), НЕ подключён к списку `CHECKS`, ничего не задеплоено.

---

## 0. Вход и метод

Прочитано целиком: `_METHOD`, `00_CHARTER`, `05_CONVENTIONS`, `07_STATE` (мандат, гейт-запись
`DQ-FRESHNESS-COVERAGE`, бриф собран сессией `DQ-FRESHNESS-COVERAGE-GEN` 2026-08-08); `07_GAPS.md`
строка `DQ-FRESHNESS-COVERAGE` (гейт `DQ-GATE-SCOPE-SPLIT-DEPLOY` снят фактом `ADR-140 §последствия`);
`02_ERP_CONTRACTS.md §схемы core` (`fact_purchases`/`fact_returns`/`fact_inventory`);
`03_PIPELINE_SPEC.md §DQ` (три порога свежести, `ADR-007`, формула «`≤2ч` → «два пропущенных
прогона»); `01_ARCHITECTURE.md §DAG` (`msklad-pipeline-hourly`, `step_purchases` NON-BLOCKING);
`11_INFRA_FACTS.md` (Cloud Scheduler: `msklad-pipeline-hourly`, `msklad-pipeline-weekly`,
`cf-inventory-trigger`, `finance-daily-update`, `loss-commission-daily-update`);
`reference/schema_dump_2026-07-28.md` §`core.fact_payments`/§`core.fact_commissionreportin`/
§`core.fact_customer_invoices`; `reference/invoices_loader_design_2026-08-02.md §9` (образец формы,
переносится без переделки); `reference/code/cf-dq/main.py`/`config.py` (текущий код-стиль);
`reference/code/cf-facts/fetch_purchases.py`/`fetch_returns.py`,
`reference/code/cf-finance/main.py`, `reference/code/cf-loss-commission/main.py`,
`reference/code/cf-inventory/main.py` (для проверки инварианта «один стамп на прогон» — заодно и
`reference/code/cf-facts/bq_ops.py §load_purchases/§load_returns`, где на деле проставляется стамп
для `fact_purchases`/`fact_returns`).

Метод: ни одного облачного вызова, кроме `bq query --dry_run` (read-only, класс A по прецеденту
`SALES-MERGE-DRYRUN`, `07_STATE.md:1518`); чтение кода — только с диска репо.

---

## 1. Каденция шести таблиц (факт, не вывод сессии)

| Таблица | Загрузчик / шаг | Расписание | Класс каденции | Источник |
|---|---|---|---|---|
| `core.fact_purchases` | `step_purchases`, `msklad-pipeline-hourly` (NON-BLOCKING) | `0 * * * *` | часовая | `11_INFRA_FACTS.md:27`, `01_ARCHITECTURE.md:84` |
| `core.fact_returns` | `step_returns`, ТОЛЬКО `msklad-pipeline-weekly` | `0 1 * * 0` | недельная | `11_INFRA_FACTS.md:27` |
| `core.fact_inventory` | `cf-inventory-trigger` | `0 21 * * *` UTC | суточная | `11_INFRA_FACTS.md:98` |
| `core.fact_payments` | `finance-daily-update` (`cf-finance`) | `0 3 * * *` Asia/Bishkek | суточная | `11_INFRA_FACTS.md:25` |
| `core.fact_commissionreportin` | `loss-commission-daily-update` (`cf-loss-commission`) | `0 3 * * *` Asia/Bishkek | суточная | `11_INFRA_FACTS.md:26` |
| `core.fact_customer_invoices` | суточный загрузчик (`INVOICES-LOADER`, T2/T3) | суточная по конструкции | суточная | `reference/invoices_loader_design_2026-08-02.md §2.4` |

## 2. Вывод порога (A): формула и число по каждой таблице

Формула (`03_PIPELINE_SPEC.md:86`, «два пропущенных прогона», применена к суточному загрузчику как
`≤2ч → ≤48ч` в `reference/invoices_loader_design_2026-08-02.md §9.2`):

```
порог_часов = 2 × период_каденции_в_часах
```

| Таблица | Каденция | Расчёт | Порог (A) |
|---|---|---|---|
| `fact_purchases` | часовая (1ч) | `2 × 1` | **2ч** |
| `fact_returns` | недельная (168ч) | `2 × 168` | **336ч** (14 суток) |
| `fact_inventory` | суточная (24ч) | `2 × 24` | **48ч** |
| `fact_payments` | суточная (24ч) | `2 × 24` = 48 номинально, **проверка (A) не заведена** — см. §4 | — |
| `fact_commissionreportin` | суточная (24ч) | `2 × 24` = 48 номинально, **проверка (A) не заведена** — см. §4 | — |
| `fact_customer_invoices` | суточная | перенесено без изменений | **48ч** (`invoices_loader_design §9.2`) |

## 3. Инвариант «один стамп `_loaded_at` на прогон» — проверка чтением кода по каждой из пяти новых таблиц

Форма проверки — `reference/invoices_loader_design_2026-08-02.md §6.4` (образец: `_loaded_at`
берётся ОДИН раз в начале прогона и проставляется всем записям).

| Таблица | Файл/строка | Механизм | Вердикт |
|---|---|---|---|
| `fact_purchases` | `reference/code/cf-facts/fetch_purchases.py:69` | `loaded_at = now_utc_str()` — один вызов ДО цикла по заказам (строка 69), значение переносится в каждую запись (строка 167) | **ПОДТВЕРЖДЁН** |
| `fact_returns` | `reference/code/cf-facts/bq_ops.py:759-760` (`load_returns`) | `loaded_at = _dt.datetime.now(...).isoformat()` — один вызов, применяется ко всем записям через `{**r, "_loaded_at": loaded_at}` (не в `fetch_returns.py` — там стампа нет вовсе, он ставится позже, в загрузочном слое) | **ПОДТВЕРЖДЁН** |
| `fact_inventory` | `reference/code/cf-inventory/main.py:157` | `loaded_at = now_utc.strftime(...)` — один вызов, передаётся параметром в `parse_stock_row()` для каждой строки (строка 172) | **ПОДТВЕРЖДЁН** |
| `fact_payments` | `reference/code/cf-finance/main.py:72` | `"_loaded_at": datetime.datetime.now(datetime.timezone.utc).strftime(...)` — вызов **ВНУТРИ** цикла `for row in resp_json.get("rows", [])`, отдельно на КАЖДУЮ строку каждой страницы пагинации | **ОПРОВЕРГНУТ** |
| `fact_commissionreportin` | `reference/code/cf-loss-commission/main.py:149` (`fetch_commission`) | `"_loaded_at": datetime.datetime.utcnow().isoformat()` — вызов **ВНУТРИ** цикла `for d in docs`, отдельно на каждую строку; `isoformat()` несёт микросекунды | **ОПРОВЕРГНУТ** |

**Почему это не мелочь.** `reference/invoices_loader_design_2026-08-02.md §6.4` называет именно
эту форму (`datetime.now()` внутри цикла, дословно «форма `cf-finance/main.py:68`» — тот же файл,
на одну строку левее найденного здесь `:72`) образцовым АНТИПАТТЕРНОМ: без единого стампа
готовность-условие «`COUNT(DISTINCT _loaded_at)` после N суточных прогонов равно ровно N» не
выполняется — прогон даёт СВОЙ разброс `_loaded_at` внутри себя, а не общий по прогону. Тот же
дефект пронаблюдён в `cf-loss-commission/main.py:123` (`fetch_loss`, соседняя функция, пишет
`core.fact_loss` — таблица вне scope этой задачи, называется для полноты картины).

**Следствие по брифу (шаг 2):** для `fact_payments` и `fact_commissionreportin` проверка (A) НЕ
написана как готовая. Открытый вопрос зафиксирован ниже (§8); порог в `config.py` для этих двух
таблиц не заведён; функции технической проверки в `main.py` не созданы (только диагностика (B),
которая от этого инварианта не зависит).

## 4. Проверки — текст и dry_run по каждой таблице

Форма (`reference/invoices_loader_design_2026-08-02.md §9.2`): (A) техническая — `TIMESTAMP_DIFF`
по `_loaded_at`, блокирующая ПО ФОРМЕ, порог из §2; (B) бизнес — `DATE_DIFF` по бизнес-дате,
диагностика, порог не назначается (осознанный отказ — нет эмпирики пауз между документами, тот же
отказ, что у `fact_customer_invoices §9.2`).

Все SQL ниже прошли `bq query --dry_run` `2026-08-09T15:07:50Z…15:08:14Z` (полный лог —
`reference/_scratch_DQ-FRESHNESS-COVERAGE_2026-08-09/dry_run_freshness_checks.log`); RC=0.

### 4.1 `core.fact_purchases` (часовая, порог A = 2ч)

Функции: `check_freshness_purchases_technical` / `check_freshness_purchases_business`
(`reference/code/cf-dq/main.py`).

```sql
-- (A) техническая
SELECT
    TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), MAX(_loaded_at), HOUR) AS load_lag_hours,
    COUNT(DISTINCT _loaded_at) AS distinct_load_stamps,
    COUNT(*) AS n_rows
FROM `msklad-bi-prod.core.fact_purchases`
```
`dry_run`: `Query successfully validated. … upper bound of 35392 bytes`.

```sql
-- (B) бизнес, бизнес-дата = order_date
SELECT DATE_DIFF(CURRENT_DATE('Asia/Bishkek'), MAX(order_date), DAY) AS business_lag_days
FROM `msklad-bi-prod.core.fact_purchases`
```
`dry_run`: `Query successfully validated. … upper bound of 35392 bytes`.

### 4.2 `core.fact_returns` (недельная, порог A = 336ч)

Функции: `check_freshness_returns_technical` / `check_freshness_returns_business`.

```sql
-- (A) техническая
SELECT
    TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), MAX(_loaded_at), HOUR) AS load_lag_hours,
    COUNT(DISTINCT _loaded_at) AS distinct_load_stamps,
    COUNT(*) AS n_rows
FROM `msklad-bi-prod.core.fact_returns`
```
`dry_run`: `Query successfully validated. … upper bound of 832 bytes`.

```sql
-- (B) бизнес, бизнес-дата = return_date
SELECT DATE_DIFF(CURRENT_DATE('Asia/Bishkek'), MAX(return_date), DAY) AS business_lag_days
FROM `msklad-bi-prod.core.fact_returns`
```
`dry_run`: `Query successfully validated. … upper bound of 832 bytes`.

### 4.3 `core.fact_inventory` (суточная, порог A = 48ч)

Функции: `check_freshness_inventory_technical` / `check_freshness_inventory_business`.

```sql
-- (A) техническая
SELECT
    TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), MAX(_loaded_at), HOUR) AS load_lag_hours,
    COUNT(DISTINCT _loaded_at) AS distinct_load_stamps,
    COUNT(*) AS n_rows
FROM `msklad-bi-prod.core.fact_inventory`
```
`dry_run`: `Query successfully validated. … upper bound of 203424 bytes`.

```sql
-- (B) бизнес, бизнес-дата = date_snapshot
SELECT DATE_DIFF(CURRENT_DATE('Asia/Bishkek'), MAX(date_snapshot), DAY) AS business_lag_days
FROM `msklad-bi-prod.core.fact_inventory`
```
`dry_run`: `Query successfully validated. … upper bound of 203424 bytes`.

### 4.4 `core.fact_payments` (суточная; порог A НЕ назначен — §3)

Функция: только `check_freshness_payments_business` (`main.py`). Проверка (A) НЕ подключена как
готовая — текст ниже приведён для протокола (SQL синтаксически валиден по `dry_run`), но в
`main.py`/`config.py` не заведена (см. §3, §8).

```sql
-- (A) техническая — СИНТАКСИЧЕСКИ ВАЛИДНА, НЕ ГОТОВА (инвариант не подтверждён)
SELECT
    TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), MAX(_loaded_at), HOUR) AS load_lag_hours,
    COUNT(DISTINCT _loaded_at) AS distinct_load_stamps,
    COUNT(*) AS n_rows
FROM `msklad-bi-prod.core.fact_payments`
```
`dry_run`: `Query successfully validated. … this query will process 41080 bytes`.

```sql
-- (B) бизнес, бизнес-дата = moment (DATE)
SELECT DATE_DIFF(CURRENT_DATE('Asia/Bishkek'), MAX(moment), DAY) AS business_lag_days
FROM `msklad-bi-prod.core.fact_payments`
```
`dry_run`: `Query successfully validated. … this query will process 41080 bytes`.

### 4.5 `core.fact_commissionreportin` (суточная; порог A НЕ назначен — §3)

Функция: только `check_freshness_commissionreportin_business`. Проверка (A) НЕ подключена как
готовая (см. §3, §8). Бизнес-дата — `moment` (тип **TIMESTAMP**, не DATE, единственная из шести
таблиц; правило суток этой таблицы — `DATE(M)` без сдвига зоны, `ADR-088 §3`: «`core.fact_returns`,
`core.fact_purchases`, `core.fact_loss`, `core.fact_commissionreportin` = `DATE(M)`»).

```sql
-- (A) техническая — СИНТАКСИЧЕСКИ ВАЛИДНА, НЕ ГОТОВА (инвариант не подтверждён)
SELECT
    TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), MAX(_loaded_at), HOUR) AS load_lag_hours,
    COUNT(DISTINCT _loaded_at) AS distinct_load_stamps,
    COUNT(*) AS n_rows
FROM `msklad-bi-prod.core.fact_commissionreportin`
```
`dry_run`: `Query successfully validated. … this query will process 1544 bytes`.

```sql
-- (B) бизнес, бизнес-дата = DATE(moment) — ADR-088 §3, правило DATE(M) этой таблицы
SELECT DATE_DIFF(CURRENT_DATE('Asia/Bishkek'), DATE(MAX(moment)), DAY) AS business_lag_days
FROM `msklad-bi-prod.core.fact_commissionreportin`
```
`dry_run`: `Query successfully validated. … this query will process 1544 bytes`.

### 4.6 `core.fact_customer_invoices` — ПЕРЕНЕСЕНО БЕЗ ИЗМЕНЕНИЙ

Источник: `reference/invoices_loader_design_2026-08-02.md §9.2` дословно (текст запроса, порог
`48ч`, обоснование "два пропущенных прогона суточного загрузчика"; инвариант «один стамп на
прогон» уже подтверждён там же, §6.4, форма `run_started_at`, не переоценивается здесь). Функции:
`check_freshness_invoices_technical` / `check_freshness_invoices_business`.

```sql
-- (A) техническая, порог 48ч
SELECT
  TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), MAX(_loaded_at), HOUR) AS load_lag_hours,
  COUNT(DISTINCT _loaded_at)                                 AS distinct_load_stamps,
  COUNT(*)                                                   AS n_rows
FROM `msklad-bi-prod.core.fact_customer_invoices`
```
`dry_run`: `Query successfully validated. … this query will process 36224 bytes`.

```sql
-- (B) бизнес, бизнес-дата = moment (DATE, уже DATE(M+6ч) по ADR-088 §3/ADR-101 §6)
SELECT DATE_DIFF(CURRENT_DATE('Asia/Bishkek'), MAX(moment), DAY) AS business_lag_days
FROM `msklad-bi-prod.core.fact_customer_invoices`
```
`dry_run`: `Query successfully validated. … this query will process 36224 bytes`.

## 5. Код — где лежит, что НЕ тронуто

- `reference/code/cf-dq/main.py` — добавлены 10 функций (`check_freshness_<table>_technical`/
  `_business` для четырёх готовых таблиц + `fact_customer_invoices`; только `_business` для
  `fact_payments`/`fact_commissionreportin`), константы `CORE_PURCHASES`/`CORE_RETURNS`/
  `CORE_INVENTORY`/`CORE_PAYMENTS`/`CORE_COMMISSIONREPORTIN`/`CORE_INVOICES`. Список `CHECKS`
  (строки существующего файла, шесть исходных чеков) **не тронут** — ни одна новая функция в него
  не входит.
- `reference/code/cf-dq/config.py` — добавлены `DQ_FRESHNESS_PURCHASES_MAX_HOURS`,
  `DQ_FRESHNESS_RETURNS_MAX_HOURS`, `DQ_FRESHNESS_INVENTORY_MAX_HOURS`,
  `DQ_FRESHNESS_INVOICES_MAX_HOURS`. Пороги для `fact_payments`/`fact_commissionreportin`
  сознательно НЕ заведены (§3, §8).
- Синтаксис обоих файлов проверен `ast.parse` (Python 3) — ошибок нет.
- Ничего не задеплоено, живой `cf-dq` не вызывался ни разу.

## 6. Сводка покрытия

| Таблица | (A) готова | (B) готова | Инвариант |
|---|---|---|---|
| `fact_purchases` | да | да | подтверждён |
| `fact_returns` | да | да | подтверждён |
| `fact_inventory` | да | да | подтверждён |
| `fact_customer_invoices` | да (перенесено) | да (перенесено) | подтверждён (в источнике §6.4) |
| `fact_payments` | **нет** | да | **опровергнут** |
| `fact_commissionreportin` | **нет** | да | **опровергнут** |

**4 из 6 таблиц получили обе готовые проверки. 2 из 6 (`fact_payments`, `fact_commissionreportin`)
получили только диагностику (B); проверка (A) для них не написана как готовая — инвариант «один
стамп на прогон» опровергнут чтением кода загрузчика, не просто «не подтверждён».**

## 7. Что это значит для следующего шага

Обе таблицы (`fact_payments`, `fact_commissionreportin`) несут ОДИН И ТОТ ЖЕ структурный дефект:
`datetime.now()`/`datetime.utcnow()` вызывается отдельно на каждую строку внутри цикла пагинации,
вместо одного стампа на весь прогон (образец правильной формы — `fetch_purchases.py:69`,
`cf-inventory/main.py:157`, `bq_ops.py:759`). Это ровно тот антипаттерн, который
`reference/invoices_loader_design_2026-08-02.md §6.4` уже назвал по имени и уже отверг для нового
загрузчика счетов, сославшись на форму `cf-finance/main.py:68` (соседняя строка того же дефекта,
что найден здесь на строке 72 того же файла).

Починка — фикс-форвард в слой-источник (`cf-finance`/`cf-loss-commission`): вынести один вызов
`datetime.now(timezone.utc)` перед циклом и переиспользовать значение для всех строк прогона, по
образцу трёх уже корректных загрузчиков. Это ПРАВКА КОДА действующих Cloud Functions — класс B
(деплой CF), вне scope этой задачи (класс A, подготовка). Она НЕ входит в `DQ-FRESHNESS-COVERAGE,
деплой` (та задача — подключение уже готовых проверок к гейту) и адресуется архитектору как
отдельный найденный дефект.

## 8. Открытые вопросы

**Q (новый, кому — архитектор).** Инвариант «один стамп `_loaded_at` на прогон» опровергнут для
`core.fact_payments` (`cf-finance/main.py:72`) и `core.fact_commissionreportin`
(`cf-loss-commission/main.py:149`, там же соседний дефект в `fetch_loss` для `core.fact_loss`,
вне scope шести таблиц брифа). Без починки этого дефекта в загрузчике проверка (A) для этих двух
таблиц не может быть написана как готовая (см. §3, §7). Гейт — не блокирует остальные пять/шесть
предметов задачи (`ADR-086`-класс: пять из шести таблиц готовы полностью).

Не блокирует ничего в scope этой сессии — обе таблицы отмечены явно, догадка не подставлена.

## 9. Самодостаточность

Документ содержит: каденцию и источник для всех шести таблиц (§1); вывод порога (A) по формуле
(§2); построчную проверку инварианта «один стамп на прогон» по коду с указанием файла и строки
(§3); полный текст обеих проверок для каждой таблицы плюс результат `dry_run` (§4); перечень правок
кода и подтверждение, что `CHECKS` не тронут (§5); сводную таблицу покрытия (§6); адресованный
открытый вопрос с диагнозом причины и рекомендацией фикс-форварда (§7-§8).
