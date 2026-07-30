# Карта происхождения — «Инвестор»/«Операционка» (продажи)

**Задача:** `SOURCE-MAP-SALES` (класс A, discovery, `ADR-079 §7a/§8`).
**Цепочка:** документ МойСклада → `core.fact_sales_profit` → `marts.sales_overview` → LS «Инвестор»/«Операционка».
**Метод:** карта снята с живого кода снапшота `cf-facts` (`reference/code/cf-facts/`, `MANIFEST.md`), не из
сравнения ответов API с `core` — по прямому назначению владельца (`ADR-079 §8`, вариант (a)).
**Чего эта карта НЕ устанавливает:** имена полей на стороне МойСклада (`REPORT-FIELDS`), численную сходимость
с МойСкладом, финальное правило моста паритета (после `REPORT-FIELDS`). Починка найденных дефектов — вне
scope, фикс-форвард отдельной задачей.

---

## 1. Провенанс

Ревизия `cf-facts-00007-xir`, регион `asia-east1`, `entryPoint=main`, `source.storageSource` —
`gs://gcf-v2-sources-420804682491-asia-east1/cf-facts/function-source.zip` (generation
`1782334223015697`), `updateTime=2026-07-29T04:05:10.487996910Z`, `state=ACTIVE`, `serviceAccountEmail=
etl-sa@msklad-bi-prod.iam.gserviceaccount.com`, `uri=https://cf-facts-xw5u2boozq-de.a.run.app`. Полная
таблица метаданных, метод снятия и известная аномалия сессии (кратковременно отключённый и восстановленный
владельцем биллинг проекта) — `reference/code/cf-facts/MANIFEST.md`.

UTC-якоря прогонов (`date -u` + `gcloud auth list` на обоих краях каждого скрипта, деградации авторизации
не было):
- Шаг 1 (инвентарь): `2026-07-29T11:58:08Z` … `11:58:16Z`
- Шаг 1 (описание аномалии биллинга, три попытки `describe`): `2026-07-29T12:11:55Z` … `12:12:21Z`,
  повторы `12:12:xxZ`
- Шаг 1 (scheduler list, билинг-ошибка): `2026-07-29T12:15:10Z` … `12:15:14Z`
- Восстановление биллинга владельцем — между сессионными прогонами (владелец подтвердил в чате)
- Шаг 2 (скачивание архива, после восстановления): `2026-07-30T10:15:35Z` … `10:15:51Z`
- Шаг 4 (запрос `Q-83`, май-2026): `2026-07-30T10:30:16Z` … `10:30:20Z`
- Шаг 5 (переверка `transferConfig`): `2026-07-30T10:30:41Z` … `10:30:45Z`

Сессия пересекла полночь Бишкека (старт 2026-07-29, продолжение после ожидания подтверждения владельца —
2026-07-30 по UTC/Бишкеку); датировка артефакта и файлов оставлена `2026-07-29` — датой, под которой бриф
сгенерирован и сессия по существу начата (чтение обязательного контекста, шаг 0), без ретро-переименования.

---

## 2. Запрос к МойСкладу

Продажи грузятся из `entity/demand` (отгрузки), COGS — из `report/profit/byvariant`, возвраты — из
`entity/salesreturn` + `entity/retailsalesreturn`. Позиции документа (`positions`) не разворачиваются в
списочном запросе (`expand=positions` не работает для списков — комментарий `fetch_demands.py:4-6`,
`fetch_purchases.py:5`, `fetch_returns.py:7-8`) — тянутся отдельным запросом на каждый документ:
`entity/demand/{id}/positions` (`fetch_demands.py:111-115`).

**Фильтр периода** (`fetch_demands.py:63-76`): `filter=moment>={date_from} 00:00:00;moment<={date_to}
23:59:59`, `order=moment,asc`. Окно определяется режимом (`main.py:66-86`):

| mode | window_days по умолчанию (код) | Совпадает с `03 §режимы cf-facts`? |
|---|---|---|
| `hourly` | `HOURLY_WINDOW_DAYS=7` (`config.py:37`, `main.py:70,76`) | Да — `03` таблица: `hourly \| 7` |
| `weekly` | `WEEKLY_WINDOW_DAYS=90` (`config.py:38`, `main.py:70,78`) | Да — `03`: `weekly \| 90` |
| `promote` | берётся из тела запроса `window_days` (`main.py:70,79-80`), используется только как partition-фильтр `MERGE`, не как окно выборки | Да по смыслу — `03`: `promote \| 7 или 90` |
| `purchases` | не читает `window_days` вообще — `_run_purchases()` (`main.py:210-253`) не принимает окно, тянет ВСЕ заказы | **Вне scope этой карты** — `core.fact_purchases`/`marts.in_transit` = `SOURCE-MAP-REST`. Одной строкой: режим есть, `03` заявляет `90`, по коду фильтра по датам нет никакого — расхождение зафиксировано здесь, карта — за `SOURCE-MAP-REST` |
| `returns` | берётся из тела запроса `window_days`, у кода **нет** дефолтного значения `730` — `main.py:70` вычисляет дефолт только для `hourly`/`weekly`, для `returns` дефолт был бы `7` (ветка `mode != "weekly"`), если тело запроса не передаёт `window_days` явно. `03` заявляет `730`. Значение `730` нигде в этом архиве не встречается (`grep -rn "730" *.py` — 0 совпадений) — это, по всей видимости, параметр вызывающего Workflow/Scheduler, не константа кода | Частично — окно `returns`-режима не проверяемо по этому архиву без `workflow.yaml` (вне архива) |

**Пагинация** (`helpers.py:71-99`): offset/limit, `PAGE_SIZE=1000` (`config.py:19`) — постранично, пока
`len(rows) < PAGE_SIZE`. **Расхождение с доком:** `04_ROADMAP.md` M-P4-02g ссылается на «`expand/limit≤100`»
(PR-16/PR-33) — в живом коде `cf-facts` лимит страницы `1000`, не `100`. Зафиксировано как факт расхождения,
не примирено.

**Rate-limit:** `MSKLAD_RPS=4` (`config.py:17`, комментарий «hard limit 5, buffer to 4»); перед КАЖДЫМ
запросом `time.sleep(1.0/MSKLAD_RPS)` = 0.25с (`helpers.py:59`) — это бюджет скорости на каждый вызов, не
только реакция на `429`. Отдельно, при получении `429` или `5xx`, `_api_get` кидает `_RetryableError`,
перехватываемый декоратором `tenacity` (`helpers.py:50-56`): до 5 попыток, экспоненциальный backoff
1–60 секунд. `fetch_returns.py` дополнительно вставляет `time.sleep(0.21)` между запросами позиций возврата
(`fetch_returns.py:27,77`) — локальный, более строгий бюджет только для этой ветки.

**Timeout:** `requests.Session.get(..., timeout=90)` (`helpers.py:60`) — совпадает с `02 §поведение API`
(`timeout=90`).

**415-на-GET:** конструкции, обрабатывающей `415`, в `cf-facts` не найдено (`grep -rn "415" *.py` — 0
совпадений). Это не противоречит доку напрямую — `02`-упоминание `415` относится к поведению API в целом
(PR-16/33/34), не обязательно к каждой CF; фиксируется как отсутствие наблюдения, не как опровержение.

---

## 3. Поля документа → колонки (staging → core)

Формула выручки, заявленная в докстринге (`fetch_demands.py:8-9`): `revenue_kgs = (price / 100) * quantity *
(1 - discount / 100)`, с конвертацией по курсу документа (см. §4).

| Поле документа МойСклада | Колонка `stg_msklad.fact_sales_staging` | Колонка `core.fact_sales_profit` | Цитата |
|---|---|---|---|
| `demand.id` | `demand_id` | входит в `transaction_id` | `fetch_demands.py:145`, `bq_ops.py:190` |
| `positions[].id` | `position_id` | входит в `transaction_id` | `fetch_demands.py:146`, `bq_ops.py:190` |
| — (вычислено) | — | `transaction_id = TO_HEX(MD5(CONCAT(demand_id,'\|',position_id)))` | `bq_ops.py:190` |
| `demand.moment` | `transaction_date_raw` (STRING) | `transaction_date` (DATE, через `PARSE_TIMESTAMP`+`DATE(...,'Asia/Bishkek')`) | `fetch_demands.py:147`, `bq_ops.py:158,191` |
| `positions[].assortment.meta.href` (UUID из href) | `product_id` | `product_id` | `fetch_demands.py:128-129,148`, `bq_ops.py:192` |
| `positions[].assortment.meta.type` | `entity_type` | `entity_type` | `fetch_demands.py:130,154`, `bq_ops.py:193` |
| `demand.agent.meta.href` (UUID) | `agent_id` | `agent_id` | `fetch_demands.py:91-94,149`, `bq_ops.py:195` |
| `positions[].quantity` | `quantity` | `sell_quantity` | `fetch_demands.py:139,150`, `bq_ops.py:196` |
| — (вычислено) | — | `return_quantity` — **захардкожено `0.0`**, не источник в документе этой CF | `bq_ops.py:197,242,265,287` |
| `positions[].price` (тыйыны), `demand.rate.value` | `price_kgs` | (не переносится напрямую в core — входит в `revenue_kgs`) | `fetch_demands.py:137-138,151` |
| `positions[].discount` | `discount` | `discount` | `fetch_demands.py:140,152`, `bq_ops.py:194,255,278` |
| — (вычислено: `price_kgs*qty*(1-discount%)`) | `revenue_kgs` | `sell_sum_kgs` **и** `revenue_kgs` (одно и то же значение дважды) | `fetch_demands.py:141,153`, `bq_ops.py:198,200` |
| — (вычислено) | — | `return_sum_kgs` — **захардкожено `0.0`** | `bq_ops.py:199,244,267,289` — см. §10 `Q-83` |
| `report/profit/byvariant.sellCostSum` (агрегат МойСклада, FIFO) | (staging `byvariant_staging.cogs_kgs`) | `cogs_kgs` = МойСклад-агрегат, **пропорционально аллоцирован** на позицию по доле выручки в недельном бакете — аллокация наша, исходная величина не наша | `fetch_byvariant.py:102,113`, `bq_ops._COGS_EXPR` `bq_ops.py:162-163,202-205` |
| — (вычислено из `cogs_kgs`) | — | `margin_kgs = revenue_kgs - cogs_kgs_аллоцированный`, NULL если COGS неизвестна | `bq_ops._MARGIN_EXPR` `bq_ops.py:165-166,206-210` |
| — (расчёт наш, поля-источника в документе нет) | — | `revenue_usd = revenue_kgs / core.dim_fx_rates.rate_kgs_per_usd` (join по дате) — DERIVED, вне паритета (`ADR-067 §4`) | `bq_ops.py:211,234-235` |
| — (расчёт наш) | — | `cogs_usd`, `margin_usd` — та же DERIVED-конвертация | `bq_ops.py:168-173,212-221` |
| `demand.salesChannel.meta.href` (UUID) + справочник `entity/saleschannel` | `sales_channel_id`, `sales_channel_name` | `sales_channel_id`, `sales_channel_name` | `fetch_demands.py:23-26,98-100,156-157`, `bq_ops.py:222-223` |
| `demand.project.meta.href` (UUID) + справочник `entity/project` | `project_id`, `project_name` | `project_id`, `project_name` | `fetch_demands.py:28-31,103-105,158-159`, `bq_ops.py:224-225` |

**Помечено явно** (`ADR-079 §1` — расчётные величины без поля-источника в документе, признак фиксируется,
вывод за паритет НЕ объявляется этой задачей): `cogs_kgs` (МойСклад-агрегат + наша аллокация),
`margin_kgs` (чистый расчёт), `revenue_usd`/`cogs_usd`/`margin_usd` (DERIVED, `ADR-067 §4`).

---

## 4. Конвертация в KGS (`ADR-010`)

**Demand-позиции** (`fetch_demands.py:137-138`):
```python
currency_rate = demand.get("rate", {}).get("value") or 1.0  # KGS per currency unit
price_kgs  = pos.get("price", 0) / 100.0 * currency_rate
```
Минорные единицы (÷100) **и** `× rate.value` документа — присутствуют. **Дефект ADR-016 (отсутствие
`× rate.value` для не-KGS) в sales-ветке cf-facts НЕ обнаружен.**

**Возвраты** (`fetch_returns.py:79,102`):
```python
currency_rate = doc.get("rate", {}).get("value") or 1.0
"sum_kgs": round(price / 100.0 * quantity * (1.0 - discount / 100.0) * currency_rate, 4),
```
Тоже несёт `× rate.value`.

**byvariant COGS** (`fetch_byvariant.py:101-105`) — **БЕЗ** `× rate.value`:
```python
sell_sum_kgs = row.get("sellSum", 0) / 100.0
cogs_kgs     = row.get("sellCostSum", 0) / 100.0
```
Только ÷100, курса нет вообще. Отличается архитектурно от позиционных фетчей: `report/profit/byvariant` —
агрегатный отчётный эндпоинт, вероятно уже отдающий суммы в базовой валюте счёта (KGS) без per-документного
курса — это предположение о семантике отчёта, а не факт из кода (проверка полей отчёта — `REPORT-FIELDS`,
класс B, вне мандата). Фиксируется как наблюдение, не как вывод об отсутствии дефекта.

**Итог по (г):** конвертация `× rate.value` присутствует на позиционном уровне (demand, returns);
на агрегатном уровне (byvariant) её нет и по семантике эндпоинта, возможно, не должно быть — не установлено
кодом этой CF, гэп на границе мандата (не блокирует эту задачу, REPORT-FIELDS впереди).

---

## 5. Правило даты

**02 §схемы core** заявляет: `transaction_date` DATE, «Дата транзакции в Asia/Bishkek».

Код (`bq_ops.py:158,191`):
```python
_PARSE_DATE = "DATE(PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%E3S', s.transaction_date_raw), 'Asia/Bishkek')"
```
Зона **явно указана** в коде — по букве критерия приёмки №5 («зона задана» vs «зона нигде не задаётся»)
это ветка **«подтверждено»**: `bq_ops.py:158`.

**Но:** обнаружено внутреннее противоречие в самом архиве `cf-facts`, которое эта явная зона не снимает.
`PARSE_TIMESTAMP(format, string)` без указания зоны трактует входную строку **как UTC** (документированное
поведение BigQuery), а второй аргумент `DATE(timestamp, 'Asia/Bishkek')` конвертирует этот UTC-инстант в
Бишкекское время — то есть код добавляет +6 часов к `moment`, ПОЛАГАЯ, что `moment` пришёл в UTC.

Тем временем `fetch_returns.py:115-122` и `fetch_purchases.py:41-50` явно утверждают обратное:
```python
# fetch_returns.py:119
# МойСклад отдаёт время в UTC+6 (Asia/Bishkek) без явного offset → прямой парсинг.
return moment_str[:10]   # без какой-либо конвертации зоны

# fetch_purchases.py:46
# МойСклад stores moments in KGT (UTC+6), so no timezone conversion needed.
return moment_str[:10]
```
Если `moment` действительно уже в Бишкекском времени (как утверждают эти два файла того же архива), то
`bq_ops.py`-конвертация для продаж применяет **лишний** сдвиг +6 часов — документы с локальным временем
≥18:00 сместились бы на следующий календарный день. Если же `moment` на самом деле в UTC (что противоречит
комментариям в `fetch_returns.py`/`fetch_purchases.py`), то `bq_ops.py` прав, а те два файла **сами**
содержат баг (берут UTC-дату, выдавая её за Бишкекскую).

**Различить эти два случая по коду архива нельзя** — нужна сверка `moment` с реальным локальным временем
конкретного документа в интерфейсе МойСклада (`Q-77`, тот же класс вопроса, что там), что требует API-вызова
и вне мандата этой сессии (класс A, без обращений к МойСклад). Фиксируется как:
- **По букве acceptance-критерия:** «Asia/Bishkek» **упоминается явно** в коде продаж (`bq_ops.py:158`) —
  02 в этом смысле подтверждён.
- **По существу:** внутри самого `cf-facts` есть архитектурное противоречие между тем, как `bq_ops.py`
  (продажи) и `fetch_returns.py`/`fetch_purchases.py` (возвраты/закупки) трактуют исходную зону `moment` —
  один явно конвертирует UTC→Bishkek, два других явно НЕ конвертируют, считая её уже локальной. Оба не могут
  быть верны одновременно. Не примирено, не выбрана «правдоподобная» версия — вынесено отдельным пунктом в
  `reference/architect_review_queue_2026-07-29-1.md` (см. §9).

---

## 6. Правило `MERGE`

Ключ: `transaction_id` (`bq_ops.py:190,237`). Partition-фильтр в `ON`-условии:
`AND T.transaction_date >= DATE_SUB(CURRENT_DATE(), INTERVAL {window_days} DAY)` (`bq_ops.py:238`) — экономит
скан партиций, не полноценный `WHERE`.

**Форма:** явный `WHEN NOT MATCHED THEN INSERT (колонки) VALUES (...)` (`bq_ops.py:258-303`) — **не**
`INSERT ROW`. Соответствует C1/`ADR-030`.

**Идемпотентность:** staging грузится `WRITE_TRUNCATE` (`bq_ops.py:115`, `stg_msklad.fact_sales_staging`;
`bq_ops.py:142`, `byvariant_staging`) — повторный прогон того же окна пересчитывает и мержит те же
`transaction_id` с теми же значениями (при неизменных исходных данных). `DELETE`-хвостов в `bq_ops.py`
нет (`grep -n "DELETE" bq_ops.py` — 0 совпадений).

**Триггер пересборки марта:** `grep -rn "trigger_marts" reference/code/cf-facts/` — **0 совпадений**.
В отличие от `cf-finance` (`03 §cf-finance`, `trigger_marts()` после `MERGE`+`DELETE`), `cf-facts` **не**
вызывает форс-триггер `sq_marts_sales_overview` ни в каком режиме. `marts.sales_overview` обновляется
исключительно по собственному расписанию SQ («каждые 2 часа», см. §7), независимо от момента промоута
в `core`.

**`fact_sales_profit_byvariant_backup`** (`CORE_BYVARIANT_BCK`): используется ТОЛЬКО как источник в
`LEFT JOIN` (`bq_ops.py:228`, `bq_ops.py:343,346`) — `grep -n "CORE_BYVARIANT_BCK" *.py` не находит ни
одного `load_table`/`INSERT`/`CREATE TABLE` с этой переменной как целью. **Этот CF в неё не пишет.**
Как и когда она наполняется (видимо, разовым bootstrap-скриптом вне этого архива) — не установлено этой
сессией, вне мандата.

---

## 7. Звено `core → marts.sales_overview` (переупаковка, `ADR-079 §2` — моста не образует)

`marts.sales_overview` — `CREATE OR REPLACE TABLE`, SQ `sq_marts_sales_overview` (Config ID
`69ff34b4-0000-2b2b-a390-14c14ef7af10`, расписание `every 2 hours`, `asia-east1`). Живой конфиг
переверен `bq show --transfer_config` (`2026-07-30T10:30:41Z`): **текст запроса совпадает** с репо-снимком
`reference/sql/sq_marts_sales_overview.sql` (2026-07-07) **побайтово по логике** — единственные различия,
найденные построчным `diff`, это длина декоративных ASCII-линий в комментариях (`── … ──`) и отсутствие
финального перевода строки в живом конфиге; ни одного отличия в SQL-конструкциях, JOIN'ах, выражениях или
именах колонок. **Совпал** (с оговоркой о косметических различиях), новый датированный снимок не создаётся
— существующий файл актуален по содержанию.

**Группировка/подмешивание:** `dim_employees` (менеджер) — `c.owner_employee_id = e.employee_id`
(`sq_marts_sales_overview.sql:117-118`), после `dim_counterparties` (страна) —
`COALESCE(c.country, 'Не указана')` (`:52`). Это ровно сочетание, названное несопоставленным в `Q-78`.

**Возвраты в марте:** CTE `returns_agg` (`:18-29`) агрегирует `core.fact_returns` по
`(return_date, product_id, agent_id)`, `LEFT JOIN` на `f.transaction_date=r.return_date AND
f.product_id=r.product_id AND COALESCE(f.agent_id,'')=COALESCE(r.agent_id,'')` (`:123-126`).
`net_revenue_kgs = ROUND(f.revenue_kgs - COALESCE(r.return_sum_kgs,0), 2)` (`:85`) — единственное место
во всей цепочке, где возвраты вообще вычитаются из выручки (см. §10, `Q-83`).

**Заголовок SQL (`:6-10`) утверждает, что блок возвратов не подключён** («раскомментировать блок
`fact_returns` JOIN… Сейчас return_sum_kgs / return_quantity = 0 (плейсхолдеры)») — **это неверно**: тело
запроса join активен и исполняется (подтверждено и текстом файла, и живым конфигом). Расхождение
заголовка с телом зафиксировано, не исправлено (правка живого SQL — класс B).

---

## 8. Расхождения кода с `02_ERP_CONTRACTS`/`03_PIPELINE_SPEC`

| # | Файл·§·строка дока | Что в доке | Что в коде | Файл:строка кода |
|---|---|---|---|---|
| 1 | `04_ROADMAP.md` M-P4-02g (ссылка на PR-16/33, `02 §поведение API`) | `expand/limit≤100` | `PAGE_SIZE=1000` | `config.py:19`, использование `helpers.py:90` |
| 2 | `02_ERP_CONTRACTS.md:49` (`§схемы core`) | `revenue_kgs` — «Нетто выручка KGS» | `revenue_kgs = sell_sum_kgs` (валовая, без вычета возвратов), `return_sum_kgs` захардкожен `0.0` | `bq_ops.py:198-200,242-244,265-267,287-289` — см. `Q-83` §10 |
| 3 | `03_PIPELINE_SPEC.md:19` (`§режимы cf-facts`) | `purchases \| 90 \| MERGE fact_purchases за 90 дней` | `_run_purchases()` не фильтрует по датам вообще (все заказы), загрузка — `WRITE_TRUNCATE`, не `MERGE` | `main.py:210-253`, `bq_ops.py:442-473` (вне scope этой карты по существу — `SOURCE-MAP-REST`, здесь фиксируется одной строкой по требованию брифа) |
| 4 | `03_PIPELINE_SPEC.md:18` | `returns \| 730 \| TRUNCATE + reload fact_returns за 2 года` | Код не содержит константы `730`; окно `returns`-режима — параметр тела запроса, дефолт для этого mode код не назначает явно (попадает в ветку `mode != "weekly"` → дефолт 7) | `main.py:68-70`, `grep -rn "730" reference/code/cf-facts/` — 0 совпадений |
| 5 | `reference/sql/sq_marts_sales_overview.sql:6-10` (заголовок файла) | Блок возвратов не подключён, `return_sum_kgs`/`return_quantity` = 0 (плейсхолдеры) | Блок `returns_agg`/`LEFT JOIN` активен и исполняется — подтверждено и телом файла, и живым `transferConfig` | `sq_marts_sales_overview.sql:17-29,79-86,123-126` |
| 6 | `02_ERP_CONTRACTS.md:41` (`§схемы core`) | `transaction_date` — «Дата транзакции в Asia/Bishkek» | Зона явно указана в коде продаж (`bq_ops.py:158`), но внутри архива противоречие: `fetch_returns.py`/`fetch_purchases.py` трактуют `moment` как уже локальное время (без конвертации), `bq_ops.py` трактует его как UTC и конвертирует +6ч. Не различено по коду — см. §5 | `bq_ops.py:158`, `fetch_returns.py:115-122`, `fetch_purchases.py:41-50` |
| 7 | `02_ERP_CONTRACTS.md:50` (`§схемы core`) | `cogs_kgs` — «Себестоимость KGS (FIFO, NULL если неизвестна)» | Величина не наш прямой FIFO-расчёт, а МойСклад-агрегат `report/profit/byvariant.sellCostSum`, пропорционально аллоцированный нами на позицию по доле выручки внутри недельного бакета — формулировка дока не различает «наш FIFO» от «FIFO МойСклада + наша аллокация» | `fetch_byvariant.py:102,113`, `bq_ops.py:162-163,202-205` |

---

## 9. Что осталось за нашей стороной

- **Имена полей на стороне МойСклада** (соответствие английских ключей API формулировкам в интерфейсе) —
  задача `REPORT-FIELDS` (класс B, мандат `ADR-079 §9`), не гейтит эту карту.
- **Численная сверка** `revenue_kgs`/`cogs_kgs`/`margin_kgs` с отчётами МойСклада — после карты, отдельная
  задача (`ADR-079 §4`).
- **Формулировка правила моста** для `reference/parity_registry.md` — после `REPORT-FIELDS`, решение
  архитектора.
- **Противоречие правила даты** (§5) и **асимметрия конвертации byvariant vs позиционных фетчей** (§4) —
  оба вынесены в `reference/architect_review_queue_2026-07-29-1.md`.
- Не идентифицирован Scheduler-job, вызывающий `cf-facts` (см. `MANIFEST.md §Известное открытое`).

---

## 10. `Q-83` — двойной вычет возвратов

**Формулировка (дословно из брифа, провенанс `PARITY-REGISTRY-BRIDGE`, 2026-07-29):** `02 §схемы core`
описывает `revenue_kgs` как «Нетто выручка KGS» при наличии отдельных `sell_sum_kgs`/`return_sum_kgs`, а
`sq_marts_sales_overview.sql` вычитает возвраты повторно.

### Половина 1 — по коду (авторитетная)

`bq_ops.py` (`_build_merge_sql`, строки 197-200, повторено в `WHEN MATCHED`/`INSERT` строки 242-244,
265-267, 287-289):
```sql
CAST(0.0 AS FLOAT64)  AS return_quantity,
s.revenue_kgs         AS sell_sum_kgs,
CAST(0.0 AS FLOAT64)  AS return_sum_kgs,
s.revenue_kgs         AS revenue_kgs,
```
`core.fact_sales_profit.revenue_kgs` и `core.fact_sales_profit.sell_sum_kgs` — **одно и то же значение**
(`s.revenue_kgs` из staging, само по себе `price_kgs*qty*(1-discount%)`, без вычета возвратов — см. §3).
`return_sum_kgs`/`return_quantity` в `core.fact_sales_profit` **захардкожены в `0.0`** для КАЖДОЙ строки —
и при `UPDATE`, и при `INSERT`. `core.fact_returns` заполняется отдельным режимом (`_run_returns`,
`load_returns`, `bq_ops.py:493-517`), но ничто в `cf-facts` не читает `core.fact_returns` для обновления
`core.fact_sales_profit.return_sum_kgs`. **Вывод по коду: `revenue_kgs` — валовая величина, идентичная
`sell_sum_kgs`; описание «Нетто выручка KGS» в `02 §схемы core` не соответствует коду.**

### Половина 2 — численный различитель, май-2026

Запрос (`reference/_scratch_SOURCE-MAP-SALES_2026-07-29/step4_q83_query.sh`, прогон `2026-07-30T10:30:16Z`
…`10:30:20Z`):

| Величина | Значение |
|---|---|
| `sales_sell_sum_kgs` (`SUM(sell_sum_kgs)`, `core.fact_sales_profit`, май-2026) | `93 522 995.53` |
| `sales_revenue_kgs` (`SUM(revenue_kgs)`, `core.fact_sales_profit`, май-2026) | `93 522 995.53` |
| `sales_return_sum_kgs` (`SUM(return_sum_kgs)`, `core.fact_sales_profit`, май-2026) | `0.00` |
| `returns_sum_kgs` (`SUM(sum_kgs)`, `core.fact_returns`, май-2026) | `570.00` |

### Отнесение к таблице разбора брифа

`sales_revenue_kgs` **побитово равно** `sales_sell_sum_kgs` (не просто «≈») — совпадает с первой строкой
таблицы разбора: **`revenue_kgs` валовая**, описание «Нетто выручка KGS» в `02` неверно, март вычитает
возвраты один раз — двойного вычета нет, есть дефект документации.

Одновременно `sales_return_sum_kgs = 0` при `returns_sum_kgs = 570.00 > 0` — совпадает и с третьей строкой
таблицы разбора: **возвраты в `core.fact_sales_profit` не заполняются** (подтверждает Половину 1: поле
`return_sum_kgs` в `core.fact_sales_profit` архитектурно всегда `0`, независимо от того, сколько реальных
возвратов есть в `core.fact_returns`); единственный вычет возвратов происходит в марте
(`sq_marts_sales_overview.sql:85`, `net_revenue_kgs = revenue_kgs − COALESCE(fact_returns.return_sum_kgs,
0)`), опирающемся на `core.fact_returns`, а не на пустое поле `core.fact_sales_profit.return_sum_kgs`.

Обе строки таблицы разбора указывают на один и тот же вывод, полученный независимо и по коду, и по
числам — совпадение, не противоречие.

**Вердикт: `Q-83` закрыт однозначно фактом. Двойного вычета возвратов НЕТ.** `core.fact_sales_profit.
revenue_kgs` — валовая выручка (совпадает с `sell_sum_kgs`); поле `return_sum_kgs` в этой таблице — мёртвый
плейсхолдер, никогда не заполняется этим CF; фактическое вычитание возвратов происходит один раз, в марте,
из `core.fact_returns`. Дефект — в формулировке `02 §схемы core` («Нетто» должно быть «Валовая»/«Gross»),
не в SQL марта.

**Кандидат в объект паритета:** по значению `sell_sum_kgs`/`revenue_kgs` в `core.fact_sales_profit`
идентичны и оба валовые — ни один из них сам по себе не является чистой выручкой с учётом возвратов.
Величина, фактически несущая вычет возвратов, — `net_revenue_kgs` в `marts.sales_overview`. Какая из трёх
колонок (`sell_sum_kgs`/`revenue_kgs` в core, или `net_revenue_kgs` в марте) должна сверяться с
МойСклад-оракулом — **решение архитектора**, не вывод этой сессии; данные для решения приведены выше.

**Починка не производится.** `02_ERP_CONTRACTS.md:49` и `sq_marts_sales_overview.sql` (правка живой
инвесторской витрины, класс B) остаются как есть; расхождение и рекомендация — в
`reference/architect_review_queue_2026-07-29-1.md`.
