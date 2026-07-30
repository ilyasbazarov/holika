# SOURCE-MAP-REST · Карта происхождения: purchases / customer_invoices / inventory / counterparty_returns

**Тип:** discovery-артефакт, снят по коду задеплоенных Cloud Functions (`ADR-079 §8`, вариант (a)).
**Класс задачи:** A (read-only облако, запись только в `/reference` и `11_INFRA_FACTS §CF`).
**Дата сессии:** 2026-07-30 (локальная, Бишкек). Бриф датирован 2026-07-29 — расхождение в один
календарный день между генерацией брифа и исполнением; порядок (`SOURCE-MAP-SALES` первая) соблюдён
и подтверждён владельцем отдельным сообщением в чате перед стартом (Шаг 0в брифа).

Не выводит: имена полей на стороне МойСклада (`REPORT-FIELDS`, класс B), численную сходимость,
формулировку правила моста для `reference/parity_registry.md`.

---

## 1. Провенанс

| Функция | Ревизия | `storageSource` (bucket/object#generation) | `updateTime` | Метод | UTC-якорь прогона |
|---|---|---|---|---|---|
| `cf-inventory` | `cf-inventory-00003-vuf` | `gcf-v2-sources-420804682491-asia-east1/cf-inventory/function-source.zip#1778486115150159` | `2026-07-30T10:04:58.467601786Z` | `gcloud storage cp` напрямую, sha256 по каждому файлу | `2026-07-30T10:47:33Z`…`10:47:49Z` |
| `cf-facts` | `cf-facts-00007-xir` | `gcf-v2-sources-420804682491-asia-east1/cf-facts/function-source.zip#1782334223015697` | `2026-07-29T04:05:10.487996910Z` | **переиспользован** снапшот `SOURCE-MAP-SALES` (`reference/code/cf-facts/` в дереве `worktrees/SOURCE-MAP-SALES`, коммит `025d599`), не перекачан этой сессией | снят сессией `SOURCE-MAP-SALES`, `2026-07-30T10:15:35Z`…`10:15:51Z` (см. `MANIFEST.md` этой CF) |
| `cf-dim`, `cf-dq`, `cf-fx`, `cf-alert` | — | скачаны и прочитаны **только для проверки** («содержит ли код `entity/invoiceout`?»), в `reference/code/` не перенесены — снапшот не входит в файлы на запись этой сессии, провенанс только в `_scratch` | — | `gcloud storage cp` в `reference/_scratch_SOURCE-MAP-REST_2026-07-30/probe-remaining-cf/`, case-insensitive grep `invoice\|payedsum\|unpaid` — 0 совпадений во всех четырёх | `2026-07-30T10:49:27Z`…`10:50:22Z` |
| `cf-finance`, `cf-loss-commission` | — | уже в репо (`reference/code/`), только повторный grep, не перекачка | — | `invoice\|payedsum\|unpaid` — 0 совпадений | тот же прогон |

Полные логи: `reference/_scratch_SOURCE-MAP-REST_2026-07-30/step1_run.log`,
`step1b_run.log`, `step1c_scheduler.log`, `step2_run.log`, `step2b_run.log`.
`date -u`/`gcloud auth list` — первой и последней командой каждого прогона, `ilyasbazarov4@gmail.com`
на всех запусках без деградации.

---

## 2. Инвентарь (Шаг 1) — 8 живых Cloud Functions

```
cf-alert  cf-dim  cf-dq  cf-facts  cf-finance  cf-fx  cf-inventory  cf-loss-commission
```

Все 8 названы где-то в репо (`01_ARCHITECTURE §топология` — семь: `cf-dim`, `cf-facts`, `cf-fx`,
`cf-inventory`, `cf-dq`, `cf-finance`, `cf-alert`; `cf-loss-commission` — отдельно, `E1-T1-MECH-INGEST`).
**Нет ни одной функции, не поименованной нигде** — случая «факт расхождения дока с реальностью через
неназванную CF» (сценарий брифа) не возникло.

`cf-inventory`: регион `asia-east1` (Вход 2 закрыт), ревизия `cf-inventory-00003-vuf`.

**`fact_customer_invoices` — обслуживающая CF НЕ УСТАНОВЛЕНА.** Гипотеза «по семейству имени = `cf-facts`»
(единственный правдоподобный кандидат, брифом же и предложенный) **опровергнута чтением кода**: режимы
`cf-facts` — `hourly | weekly | promote | purchases | returns` (`main.py:66-86`), ни один не обращается к
`entity/invoiceout`; полнотекстовый case-insensitive grep `invoice|payedsum|unpaid` по всем `.py`-файлам
всех 8 живых CF (`cf-facts`, `cf-inventory`, `cf-dim`, `cf-dq`, `cf-fx`, `cf-alert`, `cf-finance`,
`cf-loss-commission`) дал **0 совпадений**. См. §4 (customer_invoices-ветка) — это `CONTEXT GAP`, не
пропуск шага.

---

## 3. Purchases-ветка: `core.fact_purchases` → `marts.in_transit`

**(а) Источник и запрос.** `entity/purchaseorder` (эндпоинт подтверждён живым `200`,
`reference/parity_report_api_2026-07-28.md`). `fetch_purchase_positions()`,
`reference/code/cf-facts` (снапшот SALES) `fetch_purchases.py:53-178`. Двухшаговый запрос: список
заказов (`entity/purchaseorder`, опционально `filter=moment>=…;moment<=…`), затем отдельно позиции
каждого заказа (`entity/purchaseorder/{id}/positions`) — `expand=positions` в списочном режиме не
работает (докстрока `:5`, тот же класс ограничения, что у `entity/demand`).

**Расхождение с `03 §режимы cf-facts` (окно):** доккумент называет `purchases | 90 | MERGE fact_purchases
за 90 дней` (`03_PIPELINE_SPEC.md:19`). Код (`_run_purchases()`, `main.py:210-253`) вызывает
`fetch_purchase_positions(token, session=session)` **без `date_from`/`date_to`** — по докстроке
функции (`fetch_purchases.py:62-65`): «If both are None: fetch ALL orders (used for bootstrap and
WRITE_TRUNCATE refresh)». Окна в 90 дней в вызове из `main.py` нет — полный рефреш всех заказов
каждый прогон. Зафиксировано фактом, не правится (§7).

**(б) Поля ответа → колонки.** Схема `core.fact_purchases` — 19 колонок (`02_ERP_CONTRACTS.md:66-84`,
закрыта `Q-4`), полностью покрыта кодом (`bq_ops.py:399-419`, `PURCHASE_SCHEMA`):

| Поле МойСклада | Колонка `core.fact_purchases` | Цитата |
|---|---|---|
| `order.id` | `purchase_order_id` | `fetch_purchases.py:151` |
| `order.name` | `order_name` | `fetch_purchases.py:150` |
| `position.id` | `position_id` | `fetch_purchases.py:152` |
| `order.moment` (`_parse_date_kgt`) | `order_date` | `fetch_purchases.py:96-97,153` |
| `order.deliveryPlannedMoment` | `planned_delivery_date` | `fetch_purchases.py:104-105,154` |
| `position.assortment.meta.href` (parsed) | `product_id` | `fetch_purchases.py:131-133,155` |
| `order.agent.meta.href` (parsed) | `supplier_id` | `fetch_purchases.py:98-100,156` |
| `position.quantity` | `quantity_ordered` | `fetch_purchases.py:138,157` |
| `position.shipped` | `quantity_shipped` | `fetch_purchases.py:139,158` |
| `position.inTransit` | `quantity_in_transit` | `fetch_purchases.py:140,159` |
| `position.price` (÷100, × `rate.value`) | `price_kgs` | `fetch_purchases.py:141,160` |
| `position.discount` | `discount` | `fetch_purchases.py:142,161` |
| вычислено: `price_kgs × quantity_ordered × (1 − discount/100)` | `sum_kgs` | `fetch_purchases.py:145,162` |
| вычислено: `price_kgs × quantity_in_transit × (1 − discount/100)` | `in_transit_sum_kgs` | `fetch_purchases.py:147,163` |
| `order.rate.value` | `currency_rate` | `fetch_purchases.py:101,164` |
| `order.state.meta.href` (parsed) | `status_id` | `fetch_purchases.py:108-109,165` |
| `PURCHASE_ORDER_STATES[status_id]` | `status_name` | `fetch_purchases.py:110,166` |
| вычислено: `quantity_in_transit > 0` | `is_in_transit` | `fetch_purchases.py:167` |
| `now_utc_str()` | `_loaded_at` | `fetch_purchases.py:70,168` |

`status_id`/`status_name` сверены с `PURCHASE_ORDER_STATES` (`02_ERP_CONTRACTS.md:326-331` ↔
`config.py:41-46`) — **совпадают дословно** (4 UUID, включая корректную «В пути»/«Прибыл», без
перепутывания). `IN_TRANSIT_STATUS_ID` — та же строка `491d6da5-…` в обоих местах.

**(в) Зерно строки.** Строка = **позиция заказа** (`position_id`), не заказ целиком: `for pos in
positions: ... all_records.append(...)` (`fetch_purchases.py:126-169`) — один заказ разворачивается в N
строк по числу позиций. Докстрока подтверждает: «Returns flat list of position records, one row per
(order × position)» (`:65`).

**(г) Конвертация в KGS.** `price_kgs = (pos.get("price") or 0) / 100.0 * (currency_rate or 1.0)`
(`fetch_purchases.py:141`), где `currency_rate = order.get("rate", {}).get("value")` (`:101`) — **есть**
`× rate.value` (`ADR-010`). `sum_kgs`/`in_transit_sum_kgs` производные от уже сконвертированного
`price_kgs` (`:145,147`). Отдельно `order_sum_kgs = (order.get("sum") or 0) / 100.0` (`:113`) считается
**без** `× rate.value` — это переменная уровня заказа, **не записывается ни в одну колонку схемы** (не
используется дальше в функции, кроме как для потенциального лога — не найдено использования в снапшоте).
Зафиксировано как факт (мёртвая переменная), не правится.

**(д) Правило загрузки.** **НЕ `MERGE`** — `load_purchases()` (`bq_ops.py:442-473`) делает `LoadJobConfig`
c `write_disposition=WRITE_TRUNCATE` (`:463`). Докстрока подтверждает выбор: «WRITE_TRUNCATE strategy:
cheaper and simpler than MERGE for this volume... Status changes captured on every run» (`main.py:219-220`).
`ADR-030`/C1 (запрет `MERGE … INSERT ROW`) **неприменим** — в загрузчике нет `MERGE` вообще, есть только
`LoadJobConfig`. Второе расхождение с `03_PIPELINE_SPEC.md:19` (документ называет режим `MERGE`) —
зафиксировано в §7.

**(е) Ветка `returns` (`core.fact_returns`, побочно).** Уже полностью снята сессией `SOURCE-MAP-SALES`
в рамках `Q-83` (`reference/source_map_sales_2026-07-29.md` §10; код — `fetch_returns.py`,
`load_returns`/`bq_ops.py:493-517`, `WRITE_TRUNCATE` в `core.fact_returns`, без `MERGE`). Кросс-ссылка,
не повторный анализ. Единственное дополнение этой сессии: `load_returns` использует ту же стратегию
`WRITE_TRUNCATE`, что и `load_purchases` — согласуется с общим паттерном `cf-facts` (ни один из трёх
режимов записи в `core.fact_*`, снятых по этой и по `SALES`-задаче, не использует `MERGE`).

---

## 4. Customer-invoices-ветка: `core.fact_customer_invoices` → `marts.customer_invoices_ar`

**CONTEXT GAP: обслуживающая CF не установлена.** Полный инвентарь живых Cloud Functions (8 функций,
§2) прочитан построчно (`grep -rni "invoice"` по всем `.py`-файлам каждой) — ни одна не содержит кода,
обращающегося к `entity/invoiceout` или оперирующего полями `sum`/`payedSum`/`state.name` счёта. Это не
пропущенный шаг и не подстановка по аналогии (запрещена `ADR-079 §8`) — это установленный факт
отрицательного результата дискавери, доступного этой сессии (инструменты CLI, класс A).

**Что удалось установить без кода — из `bq show --transfer_config` на живой `sq_marts_customer_invoices_ar`
(read-only, Шаг 9, попутно):**

```sql
SELECT
  i.agent_id, i.agent_name,
  COALESCE(c.country, 'Не указана') AS country,
  i.state_name, i.state_id,
  COUNT(DISTINCT i.invoice_id) AS invoice_count,
  ROUND(SUM(i.sum_kgs), 2) AS total_invoiced_kgs,
  ROUND(SUM(i.payed_sum_kgs), 2) AS total_paid_kgs,
  ROUND(SUM(i.unpaid_sum_kgs), 2) AS total_unpaid_kgs,
  MIN(i.moment) AS earliest_invoice_date,
  MAX(i.moment) AS latest_invoice_date,
  COUNTIF(i.payment_planned IS NOT NULL AND i.payment_planned < CURRENT_DATE() AND i.unpaid_sum_kgs > 0) AS overdue_count
FROM `msklad-bi-prod.core.fact_customer_invoices` i
LEFT JOIN `msklad-bi-prod.core.dim_counterparties` c ON i.agent_id = c.agent_id AND c.scd2_is_current = TRUE
GROUP BY i.agent_id, i.agent_name, c.country, i.state_name, i.state_id
ORDER BY total_unpaid_kgs DESC
```

Это подтверждает **имена колонок** `core.fact_customer_invoices`, которые уже известны из
`reference/schema_dump_2026-07-28.md` (14 колонок): `invoice_id`, `agent_id`, `agent_name`, `state_id`,
`state_name`, `sum_kgs`, `payed_sum_kgs`, `unpaid_sum_kgs`, `moment`, `payment_planned` среди них. Это
**переупаковка march-SQL**, не карта происхождения (`ADR-079 §2`) — она не говорит, откуда в `core`
взялись эти значения, кто и как их туда загрузил, какая формула стоит за `unpaid_sum_kgs`
(`sum − payed` посчитано нами или взято полем ответа), и есть ли `× rate.value`.

**(а)-(г) не выведены** — источник, формула, зерно строки, конвертация в KGS, правило `MERGE`/загрузки
для этой ветки остаются `CONTEXT GAP`. Не закрывается догадкой (`_METHOD §6`). Возможные объяснения,
ни одно не подтверждено этой сессией и не выбирается: (i) таблица загружена CF, впоследствии удалённой/
переименованной (Q-3-класс — исходный код не версионирован до `CODE-REPO-STANDUP`); (ii) загружена
разовым ручным скриптом/бэкфиллом, не оформленным как деплой CF; (iii) существует CF, зарегистрированная
под именем, не входящим в инвентарь `gcloud functions list`/`gcloud run services list` этого проекта
(маловероятно — обе команды опрашивают один и тот же ресурс `Function`/gen2-Cloud-Run-сервис по всему
проекту, не по региону, полнота инвентаря не под вопросом в рамках этих инструментов).

**Дальнейший шаг (не эта сессия):** discovery следующего порядка — поиск по BigQuery job history
(`INFORMATION_SCHEMA.JOBS_BY_PROJECT`, метод уже применялся в `FX-MAY-WINDOW`, `Q-70`/D2) на предмет
исторических `LOAD`/`bq load` заданий в `core.fact_customer_invoices`, которые могли бы назвать
принципала-загрузчика (сервис-аккаунт, время, источник GCS-объекта, если был). Вне мандата и вне шагов
этого брифа буквально — не исполнено этой сессией, фиксируется как рекомендация.

---

## 5. Inventory-ветка: `core.fact_inventory` → `stock`-компонент `marts.inventory_health`

**(а) Источник и запрос.** `report/stock/all` (подтверждён живым `200`,
`reference/parity_report_api_2026-07-28.md`), **только этот эндпоинт** — `report/stock/bystore` в коде
`cf-inventory` не вызывается (единственная функция сети — `paginate_report_stock()`,
`helpers.py:43-80`, жёстко зашит URL `f"{MSKLAD_BASE}/report/stock/all"`, `:57`). Параметры:
`stockMode=all` (включая нулевые/отрицательные остатки), `quantityMode=all` (включая нулевой `quantity`,
иначе дефолт `nonEmpty` отфильтровал бы OOS-товары) — `helpers.py:62-67`, докстрока `:44-49`. Пагинация
`limit=1000`, `offset` инкремент, `sleep(1/4)` между страницами (`MSKLAD_RPS=4`, `config.py:23`) —
чуть ниже официального лимита 5 rps.

**(б) Поля ответа → колонки.** Схема `core.fact_inventory` — 11 колонок (`02_ERP_CONTRACTS.md:103-117`,
закрыта `Q-4`), полностью покрыта (`main.py:25-37`, `FACT_INVENTORY_SCHEMA`):

| Поле ответа `report/stock/all` | Колонка `core.fact_inventory` | Цитата |
|---|---|---|
| вычислено: `now_kgt.date()` | `date_snapshot` | `main.py:156,56` |
| `row.meta.href` (parsed) | `product_id` | `main.py:48,57` |
| `row.meta.type` | `entity_type` | `main.py:49,58` |
| `row.name` | `name` | `main.py:59` |
| `row.stock` | `stock` | `main.py:60` |
| `row.reserve` | `reserve` | `main.py:61` |
| `row.inTransit` | `in_transit` | `main.py:62` |
| `row.quantity` | `quantity_available` | `main.py:63` |
| `row.stockDays` | `stock_days` | `main.py:64` |
| `row.price` (÷100) | `cost_kgs` | `main.py:52-53,65` |
| вычислено (UTC ISO) | `_loaded_at` | `main.py:157,66` |

Покрыты все требуемые брифом поля: `stock`, `reserve`, `in_transit`, `quantity_available`, `cost_kgs`.

**Расчётные величины `marts.inventory_health` вне `core.fact_inventory`** (`coverage_days_90d_calendar`,
`coverage_days_true_adt`, `is_low_stock`, `is_oos`, `is_toxic`) — считаются мартовым SQL поверх факта
(§9), **не приходят из МойСклада** — уже адъюдицировано `ADR-079 §1`, этот артефакт только фиксирует
признак, вывод за паритет не переобъявляет.

**(в) Зерно строки.** `date_snapshot` — **дата снятия снимка**, вычисляется в момент запуска CF
(`now_kgt.date().isoformat()`, `main.py:151-156`), **не** дата документа МойСклада (у отчёта остатков
документа-источника и нет — это моментальный срез). Частота: ежедневно, Cloud Scheduler
`cf-inventory-trigger` `0 21 * * *` UTC = 03:00 KGT (§8) — совпадает с докстрокой `main.py:4`.

**(г) Конвертация в KGS + правило загрузки.**

`cost_kgs = round(float(price_raw) / 100.0, 4)` (`main.py:52-53`) — **только** деление на 100 (минорные
единицы, тыйыны → KGS), **нет `× rate.value`**. Не FIFO-расчёт нашей стороны (в отличие от
`fact_sales_profit.cogs_kgs`, `SOURCE-MAP-SALES`): `price` — поле, которое **МойСклад сам возвращает**
в ответе `report/stock/all` (внутренняя себестоимость остатка по методологии МойСклада, метод расчёта
внутри МойСклада не виден и не наш код не переопределяет). Флаг (не факт о дефекте, не правится этой
сессией): `report/stock/all` не несёт поля `currency`/`rate` в ответе (по коду — ни одно такое поле не
читается), то есть либо (i) МойСклад отдаёт себестоимость остатков только в базовой валюте счёта (KGS)
без множественной валюты по построению отчёта, либо (ii) многовалютные остатки конвертируются на
стороне МойСклада до отдачи в API. Ни одна гипотеза не подтверждена и не выбирается этой сессией
(вне мандата — численная/семантическая проверка на стороне МойСклада относится к `REPORT-FIELDS`,
класс B).

**Загрузка:** НЕ `MERGE`. `delete_todays_partition()` (`main.py:112-124`, `DELETE FROM
core.fact_inventory WHERE date_snapshot = '<today>'`) перед `load_to_bq()`
(`main.py:127-145`, `LoadJobConfig` c `write_disposition=WRITE_APPEND`). Идемпотентность —
delete-затем-append по партиции даты, докстрока подтверждает (`main.py:5-6`: «Стратегия: APPEND в
партицию date_snapshot. Идемпотентность: DELETE сегодняшней партиции перед APPEND»). DQ-гейт встроен
в саму CF (`run_dq_gate()`, `main.py:71-108`): не-пустой ответ, `product_id` заполнен у всех,
`currency_normalization` (средняя себестоимость < 500 000 KGS — тот же класс DQ-чека, что в
`03 §DQ`/`ADR-019/07_STATE Q-20`, но с другим порогом и локально в этой CF, не в `cf-dq`), `stock_days
>= 0`. Провал любого чека — `raise ValueError`, `core` не трогается (`main.py:107-108`).

---

## 6. `msklad_counterparty_returns` — исход (b): объект не найден инструментами BigQuery CLI

`bq ls --transfer_config --transfer_location=asia-east1` — полный листинг 13 `transferConfig`
(совпадает с `reference/sql/README.md`): `sq_audit_dim_products_snapshot`,
`sq_audit_dim_counterparties_snapshot`, `sq_audit_dim_employees_snapshot`, `sq_marts_inventory_health`,
`sq_marts_sales_overview`, `sq_marts_gmroi_by_folder`, `sq_marts_gmroi`, `sq_marts_abc_xyz`,
`sq_marts_in_transit`, `sq_marts_supplier_price_history`, `sq_marts_weight_flow`, `sq_marts_expenses`,
`sq_marts_customer_invoices_ar`. Ни одно имя не похоже на «returns»/«counterparty».

`bq ls --format=prettyjson msklad-bi-prod:marts` — все 10 объектов датасета `marts` имеют
`"type": "TABLE"` (`abc_xyz`, `customer_invoices_ar`, `expenses`, `expenses_staging`, `gmroi`,
`gmroi_by_folder`, `in_transit`, `inventory_health`, `sales_overview`, `supplier_price_history`,
`weight_flow`) — **ни одного `VIEW`**. `bq ls --routines msklad-bi-prod:marts` и `...:core` — **пустой
список** (0 routines в обоих датасетах).

**Вывод фактом:** на дату этой сессии `msklad_counterparty_returns` **не является** BigQuery
scheduled-query-объектом, VIEW или routine, обнаружимым инструментами `bq`/`gcloud` из этой сессии.
Согласуется с гипотезой брифа (i) — custom-SQL встроен непосредственно в источник данных Looker Studio
(BigQuery Custom Query), не наблюдаемый инструментами командной строки без доступа к конфигурации LS.
**Discovery, доступный классу A этой сессии, исчерпан.** Остаётся входом для `Q-79`, не закрытием —
следующий шаг требует доступа к настройкам Looker Studio (вне мандата класса A и вне инструментов CLI
по построению, не секрет и не деплой).

Логи: `reference/_scratch_SOURCE-MAP-REST_2026-07-30/step6_transferconfigs_full.json`.

---

## 7. Расхождения кода с доками (без примирения)

| № | Файл · § · строка | Что в доке | Что фактически в коде | Цитата |
|---|---|---|---|---|
| 1 | `01_ARCHITECTURE.md §топология` (таблица «CF ↔ что грузит») | Не называет CF для `core.fact_customer_invoices` (уже отмечено брифом) | Подтверждено **глубже**: ни одна из 8 живых CF вообще не содержит кода для этой таблицы — не пробел в документации, а отсутствие видимого загрузчика в текущем деплое | §4 этого артефакта, `grep -rni invoice` — 0 совпадений во всех 8 CF |
| 2 | `03_PIPELINE_SPEC.md:19` (`§режимы cf-facts`) | `purchases \| 90 \| MERGE fact_purchases за 90 дней` | (i) `_run_purchases()` вызывает `fetch_purchase_positions()` без `date_from`/`date_to` → полный рефреш ВСЕХ заказов, не окно 90д; (ii) загрузка — `LoadJobConfig(write_disposition=WRITE_TRUNCATE)`, не `MERGE` | `main.py:210-253`, `fetch_purchases.py:62-65`, `bq_ops.py:460-466` |
| 3 | `03_PIPELINE_SPEC.md:18` (уже отмечено `SOURCE-MAP-SALES` §7 п.4 для `fact_returns`, кросс-ссылка) | `returns \| 730 \| TRUNCATE + reload fact_returns за 2 года` | Константа `730` в коде не встречается; окно параметр тела запроса, дефолт при отсутствии — 7 (не 730) | `main.py:68-70`, кросс-ссылка `reference/source_map_sales_2026-07-29.md:253` |
| 4 | `11_INFRA_FACTS.md §CF cf-finance` строка 27 | Называет джобу `cf-inventory-trigger` (имя + расписание `0 21 * * *`) без `attemptDeadline` | `attemptDeadline: 180s` — меньше серверного `timeoutSeconds` CF (`540s`) — тот же класс риска, что `ADR-023` нашла у `finance-daily-update` до фикса | `reference/_scratch_SOURCE-MAP-REST_2026-07-30/step1c_scheduler.log` |

Ничего из перечисленного не правится этой сессией (`CLAUDE.md §Граница контракта`) — фикс-форвард в
нужный слой отдельной задачей.

---

## 8. `11_INFRA_FACTS §CF` — новый слот `cf-inventory`

Внесено в `11_INFRA_FACTS.md` (см. коммит сессии) по образцу соседних блоков. Слот `cf-facts` этой
сессией не тронут (правит `SOURCE-MAP-SALES`).

---

## 9. Звенья `core → marts.*` — переупаковка, моста не образует (`ADR-079 §2`)

Read-only переверка живых `transferConfig` против снимков `reference/sql/` от 2026-07-07:

| Март | Config ID | Расписание (`11 §SQ`) | Результат переверки |
|---|---|---|---|
| `marts.in_transit` | `6a0aa537-0000-260f-b391-d43a2cee6b87` | `every 24 hours` | **Совпал.** Байт-в-байт идентичен `reference/sql/sq_marts_in_transit.sql` (единственное различие в извлечённой строке — отсутствие завершающего `\n`, артефакт JSON-парсинга запроса, не содержимого). `ADR-062 §10` («настоящей политике соответствует, правке не подлежит») — подтверждён актуальным. |
| `marts.customer_invoices_ar` | `6a23f3ea-0000-2952-853d-582429be7ecc` | ежедневно, якорь 10:00 UTC | **Совпал.** Байт-в-байт идентичен `reference/sql/sq_marts_customer_invoices_ar.sql`. |
| `marts.inventory_health` | `69fd92d9-0000-2372-ad37-582429aca3ec` | `every 24 hours` | **Разошёлся косметически.** Все не-комментарные строки SQL идентичны (`diff` без строк-комментариев — пусто); различие только в длине декоративных строк-разделителей внутри комментариев (`-- ── … ──`, число `─` разнится на несколько символов в 8 местах). Свежий снимок положен новым файлом `reference/sql/sq_marts_inventory_health_2026-07-30.sql`, существующий `reference/sql/sq_marts_inventory_health.sql` не тронут. |

Описание колонок/группировки/фильтров/dim-подмешивания трёх мартов — уже задокументировано в
`03_PIPELINE_SPEC.md §marts` (полей `marts.in_transit`, `marts.inventory_health`,
`marts.customer_invoices_ar`, канонический SQL приведён дословно) — не переносится сюда повторно
(`ADR-079 §2`: это переупаковка `core`, не мост, и уже описана в другом доке этой же сессией её не
трогаем). `msklad_counterparty_returns` — объекта нет (§6), звено не строится.

---

## 10. Что осталось за нашей стороной (границы этой задачи)

- Имена полей на стороне МойСклада (`entity/purchaseorder`, `entity/invoiceout`, `report/stock/all`) —
  `REPORT-FIELDS`, класс B.
- **Загрузчик `core.fact_customer_invoices` — установлен НЕ полностью** (§4): среди живых CF не найден.
  Discovery следующего порядка (job history `INFORMATION_SCHEMA.JOBS_BY_PROJECT`) не исполнен этой
  сессией — рекомендация, не факт.
- Численная сверка трёх денежных величин (`in_transit_sum_kgs`, `unpaid_sum_kgs`/`sum_kgs`/`payed_sum_kgs`,
  `cost_kgs`) с эталоном МойСклада — вне scope, идёт после карты.
- Формулировка правила моста для `reference/parity_registry.md` — после `REPORT-FIELDS`.
- Доступ к конфигурации Looker Studio (для `msklad_counterparty_returns`, если custom-SQL встроен там) —
  вне инструментов CLI, вне мандата класса A по построению.
