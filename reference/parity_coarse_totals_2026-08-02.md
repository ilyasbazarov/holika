# FILE: reference/parity_coarse_totals_2026-08-02.md

# `PARITY-COARSE-TOTALS` — грубые итоги трёх неизмеренных пар реестра паритета

**Задача:** `PARITY-COARSE-TOTALS`, класс B, мандат выдан поимённо `ADR-108 §1`
(`reference/process_freeze_2026-08-02.md §5`), прецедент формы `ADR-092 §1`.
**Дата (Бишкек):** 2026-08-02 · **SHA старта:** `b86f0eba0d8843e17789f1b85f4cdcb531f95f36`
**Дерево/ветка:** `worktrees/PARITY-COARSE-TOTALS` / `s/PARITY-COARSE-TOTALS`
**Личность на старте и в конце каждого скрипта:** `ilyasbazarov4@gmail.com` (совпадает во всех
запусках, `gcloud auth list`, первой и последней командой).
**Скрипты и логи:** `reference/_scratch_PARITY-COARSE-TOTALS_2026-08-02/` — `step1_grain.sh`/`.log`,
`step2_our_side.sh`/`.log`, `step2b_invoice_count.sh`/`.log`, `step3_source_side.py`/`.sh`/`.log`,
сырые тела ответов API (`step3_stock_all_page*.json`, `step3_purchaseorder_page*.json`,
`step3_purchaseorder_<id>_positions.json`, `step3_invoiceout_page1.json`/`page2.json`,
`step3_invoiceout_non_kgs.json`, `step3_summary.json`).
**Токен:** прочитан одной командой в переменную окружения `MSKLAD_TOKEN`
(`gcloud secrets versions access latest --secret=msklad-token --project=msklad-bi-prod`), нигде не
напечатан (в логе — только длина строки, `40` символов); `set -x` не использовался. Форма заголовка
авторизации — дословно `reference/code/cf-finance/main.py:39`:
`{"Authorization": f"Bearer {token}", "Accept-Encoding": "gzip"}`. Перед `git add` выполнена проверка
`grep -rF -- "$MSKLAD_TOKEN" reference/_scratch_PARITY-COARSE-TOTALS_2026-08-02/ reference/parity_coarse_totals_2026-08-02.md` —
вывод пуст (см. `grep_token_check.log` в том же каталоге).

**Ни одна причина расхождения не устанавливалась.** Гипотезы, где возникли, помечены явно как
непроверенные этой сессией.

---

## Шаг 1 — зерно пары «Счета покупателям»

`reference/sql/sq_marts_customer_invoices_ar.sql` (полный файл процитирован в
`step1_grain.log`): запрос читает `FROM core.fact_customer_invoices` БЕЗ единого `WHERE` по дате
(`grep -n "WHERE"` — 0 совпадений), агрегирует `SUM`/`COUNT` по группам `agent_id, agent_name,
country, state_name, state_id`. Дата в запросе используется только внутри `COUNTIF` для
`overdue_count` (сравнение с `CURRENT_DATE()`), не как фильтр периода. Контрольная цитата
`03_PIPELINE_SPEC.md:240`: «LS источник: `msklad_customer_invoices_ar` (Custom Query, без date
range — snapshot)».

**Вывод:** `marts.customer_invoices_ar` — снимок «на сейчас» (все счета, что лежат в
`core.fact_customer_invoices` на момент пересборки витрины), не запрос по периоду. Окно сравнения
в Шаге 4 — тоже «на сейчас»: сторона источника берётся БЕЗ фильтра по `moment` (все документы
`entity/invoiceout`), это симметрично тому, что делает мост.

---

## Шаг 2 — наша сторона, одним окном (UTC)

**Окно снятия (наша сторона, BigQuery):** `2026-08-02T09:20:24Z` … `2026-08-02T09:20:54Z`
(`step2_our_side.log`) плюс добавочный запрос `2026-08-02T09:29:05Z` … `2026-08-02T09:29:08Z`
(`step2b_invoice_count.log`, только для числа счетов, не для сумм).

| Витрина | Строк | Величины |
|---|---|---|
| `marts.inventory_health` | 312 | `SUM(stock) = 115 749,0`; `date_snapshot = 2026-08-01` (витрина не пересобиралась в момент замера — устарела на сутки относительно живого источника, это часть результата, не помеха, ловушка L3 брифа) |
| `marts.in_transit` | 268 (позиции, отфильтрованные по статусу и `in_transit_sum_kgs > 0` — так устроен сам March-SQL) | `SUM(in_transit_sum_kgs) = 78 748 543,05` |
| `marts.customer_invoices_ar` | 546 (строк-групп по контрагенту+статусу, НЕ число счетов) | `SUM(total_invoiced_kgs) = 515 984 467,78`; `SUM(total_paid_kgs) = 393 262 729,12`; `SUM(total_unpaid_kgs) = 122 721 738,66`; `SUM(invoice_count) = 4058` счетов (сверяется с известной цифрой `07_STATE §Контрольные цифры`: «`core.fact_customer_invoices`: 4058 записей») |

---

## Шаг 3 — сторона источника, живые GET (окно UTC `2026-08-02T09:24:27Z … 09:28:04Z`)

Стоп-условие «3+ подряд `401`/пустых тел» не сработало ни разу — все вызовы вернули `200` с
непустым телом (см. `step3_source_side.log`).

### `report/stock/all`
Ключи первой строки данных: `externalCode, folder, image, inTransit, meta, name, price, quantity,
reserve, salePrice, stock, stockDays, uom`. Один заход, `limit=1000`, `meta.size = 313`.
**Строк = 313, `SUM(stock) = 115 887,0`.**

### `entity/purchaseorder`, фильтр по статусам «В пути»/«Прибыл частично»
Ключи первой строки данных заказа: `accountId, agent, agentAccount, applicable, created,
deliveryPlannedMoment, description, externalCode, files, group, id, invoicedSum, meta, moment,
name, organization, organizationAccount, owner, payedSum, positions, printed, project, published,
rate, shared, shippedSum, state, store, sum, supplies, updated, vatEnabled, waitSum`.
Всего заказов (без фильтра) — 211; в статусах «В пути»/«Прибыл частично» — **19** (12 + 7).
Статус найден по `state.meta.href` → UUID, сопоставленному со словарём
`reference/code/cf-facts/fetch_purchases.py:20-26` (тот же способ, что уже применяет ингест —
не изобретён заново).

Позиции заказа (ключи первой строки данных): `accountId, assortment, discount, id, inTransit,
meta, price, quantity, shipped, vat, vatEnabled`. Для каждой из 19 заказов — позиции; сумма
считается по формуле, дословно взятой из уже задеплоенного ингеста
(`reference/code/cf-facts/fetch_purchases.py:141/147`): `price_kgs = (price/100) × rate.value`,
`in_transit_sum_kgs = price_kgs × inTransit × (1 − discount/100)`. Эта формула — не новая политика
конвертации валют, а воспроизведение уже принятой (та же, что использует наш собственный ингест
для получения самой сравниваемой величины `in_transit_sum_kgs`); без неё сравнение с грубыми
единицами МойСклад было бы бессмысленно (порядок, в котором клиент вручную читает «остаток к
поставке» по позициям заказа, — тот же, см. `parity_registry.md` строка 22).

**Наблюдение (не установление причины):** все 19 совпавших заказов номинированы не в KGS — курс
документа `87,5` либо `90,0` сом (валюта `entity/currency/3ea7aa1b-2c68-11ef-0a80-117500188e00`,
ISO-код этой валюты не резолвился отдельным запросом, не входило в объём замера). Это факт о
периметре найденных документов, не гипотеза о причине расхождения.

**Итог: `SUM(in_transit_sum_kgs) = 78 748 543,05`.**

### `entity/invoiceout`
Ключи первой строки данных: `accountId, agent, applicable, contract, created, demands,
externalCode, files, group, id, meta, moment, name, organization, organizationAccount, owner,
payedSum, paymentPlannedMoment, positions, printed, project, published, rate, salesChannel, shared,
shippedSum, state, store, sum, updated, vatEnabled`. Без фильтра по дате (симметрично зерну Шага 1),
`expand=rate.currency` для распознавания валюты документа, `limit=100` (по правилу «`expand` +
`limit>100` тихо роняет `expand`», `02 §поведение API`), 46 страниц, `meta.size = 4526`.

**Валюта не конвертируется этим замером (ловушка L2 брифа).** Суммы `sum`/`payedSum` взяты
буквально ÷100 (минорные единицы → нативная валюта документа), курс НЕ применялся — конвертация
`entity/invoiceout` → `core.fact_customer_invoices` не задокументирована (`Q-82`: «загрузчик не
установлен»), придумывать правило конвертации в этой сессии запрещено.

**Итог по всем 4526 документам (без разделения по валюте):**
- `n_rows = 4526`
- `SUM(sum)/100 = 558 493 952,97`
- `SUM(payedSum)/100 = 449 711 548,89`
- `unpaid (= sum − payedSum) = 108 782 404,08`

**Не-KGS документы — отдельной строкой (не приведено к сому):** `1965` документов из `4526`
(`43,4 %` количества) несут `rate.currency.isoCode ≠ "KGS"`; сумма таких документов в их
собственной нативной валюте (без конвертации) — `186 304 933,85`. Список сохранён
(`step3_invoiceout_non_kgs.json`).

---

## Шаг 4 — три разности

### Пара 1 — Остатки товаров

| | Источник (`report/stock/all`) | Наша сторона (`marts.inventory_health`) | Разность |
|---|---|---|---|
| Строк | 313 | 312 | 1 (0,32%) |
| `SUM(stock)` | 115 887,00 | 115 749,00 | **138,00 (0,12%)** |

Окно: источник снят `2026-08-02T09:24:27Z…09:28:04Z`; наша сторона — снимок витрины датирован
`2026-08-01` (пересборки в момент замера не было, ловушка L3).

### Пара 2 — Заказы поставщикам «в пути»

| | Источник (`entity/purchaseorder`, позиционная формула) | Наша сторона (`marts.in_transit`) | Разность |
|---|---|---|---|
| Гранула | 19 заказов | 268 строк-позиций (по построению SQL) | разная гранулярность, не сравнивается напрямую |
| `SUM(in_transit_sum_kgs)` | 78 748 543,05 | 78 748 543,05 | **0,00 (0,00%)** |

Окно: оба среза внутри `2026-08-02T09:20:24Z…09:28:04Z` (наша сторона снята раньше источника на
несколько минут в пределах одной сессии).

### Пара 3 — Счета покупателям

| | Источник (`entity/invoiceout`, без конвертации валют) | Наша сторона (`marts.customer_invoices_ar`, KGS) | Разность |
|---|---|---|---|
| Число счетов | 4526 | 4058 | **468 (10,34%)** |
| Выставлено (`sum`) | 558 493 952,97 | 515 984 467,78 | **42 509 485,19 (7,61%)** |
| Оплачено (`payedSum`) | 449 711 548,89 | 393 262 729,12 | **56 448 819,77 (12,55%)** |
| Не оплачено (`sum − payedSum`) | 108 782 404,08 | 122 721 738,66 | **−13 939 334,58 (−12,81% от источника)** |

Окно: оба среза внутри `2026-08-02T09:20Z…09:29Z`, зерно — снимок «на сейчас» без периода (Шаг 1).
**Гипотеза, не проверенная этой сессией:** часть разности по счетам может объясняться тем же
классом, что и не-KGS документы (`43,4 %` количества источника — не в KGS), и/или периметром типов
документов, который ингест мог не покрыть полностью (аналог механизма, найденного `ADR-103` для
продаж). Причина НЕ устанавливалась.

---

## Что НЕ делалось этой сессией (по scope брифа)

- Причины ни одного из трёх расхождений не устанавливались.
- Правила-мосты `Q-80`/`Q-81`/`Q-82` не выводились.
- Ни одна витрина, Custom Query, конфигурация или код не правились.
- Построчная сверка не производилась.
- Реестр паритета расширен не был; правились только строки 21–23 колонки «Статус сходимости».
