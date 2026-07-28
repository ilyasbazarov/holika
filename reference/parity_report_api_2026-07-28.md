# /reference/parity_report_api_2026-07-28.md — Discovery report-API МойСклад ↔ страницы UI (PARITY-REGISTRY, Шаг 2)

**Задача:** `PARITY-REGISTRY` (discovery-часть, класс B, мандат `ADR-076 §3a`).
**Дата замера (UTC):** 2026-07-28, три скрипта, ~16:08–16:14 UTC.
**Личность на старте и в конце каждого скрипта:** `ilyasbazarov4@gmail.com` (совпадает, `gcloud auth list`).
**Логи:** `reference/_scratch_PARITY-REGISTRY_2026-07-28/run_step2.log`, `run_step2b.log`, `run_step2c.log`.
**Токен:** прочитан в переменную окружения одной командой `gcloud secrets versions access latest --secret=msklad-token --project=msklad-bi-prod`, нигде не напечатан (в логах — только длина строки, `40` символов). Форма заголовка авторизации — дословно из `reference/code/cf-finance/main.py` строка 39: `{"Authorization": f"Bearer {token}", "Accept-Encoding": "gzip"}`.
**Метод:** Python `requests`, не `curl` (`02 §поведение МойСклад API`); `time.sleep(0.25)` после каждого запроса; `limit` не выше 100 при `expand=` (для `entity/*` запросов); GET без `Content-Type`.
**Стоп-условие Шага 2 брифа (3+ подряд `401`/пустых тел) — НЕ сработало ни разу**: во всех 18 живых вызовах — либо `200` с телом, либо `404` с телом ошибки (`code 1002`, «Неопознанный путь» — определённый отрицательный факт о несуществующем пути, не гэп авторизации).

---

## Кандидаты report-API (уровень (i) по `ADR-067 §2`)

Список кандидатов собран по структуре публичной документации МойСклад JSON API 1.2 (группа `report/*`), релевантной поверхностям Шага 1 (прибыльность, продажи, деньги, остатки, обороты, взаиморасчёты, дашборд) — не по имени наших страниц LS.

| Endpoint | Период запроса (UTC) | HTTP | Верхнеуровневые ключи / вердикт | Скрипт·лог |
|---|---|---|---|---|
| `report/profit/byproduct` | 2026-05-01…2026-06-01 | `200` | `context, meta, rows` — прибыльность по товарам за май-2026; `meta.size=279` | `run_step2.log` |
| `report/profit/bycounterparty` | 2026-05-01…2026-06-01 | `200` | `context, meta, rows` — прибыльность по контрагентам; `meta.size=64` | `run_step2.log` |
| `report/sales/byproduct` | 2026-05-01…2026-06-01 | `404` | путь не существует (`code 1002`) — подтверждённое отсутствие, не гэп | `run_step2.log` |
| `report/sales/bycounterparty` | 2026-05-01…2026-06-01 | `404` | путь не существует | `run_step2.log` |
| `report/profit/bysalesreturn` | 2026-05-01…2026-06-01 | `404` | путь не существует — отдельного report-эндпоинта для возвратов покупателей нет | `run_step2b.log` |
| `report/counterparty/debt` | — | `404` | путь не существует | `run_step2.log` |
| `report/counterparty/debt/all` | — | `404` | путь не существует | `run_step2b.log` |
| `report/money/plotseries` | 2026-05-01…2026-06-01, `interval=day` | `200` | `context, meta, credit, debit, series` — движение денег по дням, БЕЗ разреза по статье/категории | `run_step2.log` |
| `report/money/turnover` | 2026-05-01…2026-06-01 | `404` | путь не существует | `run_step2b.log` |
| `report/money/byaccount` | — | `200` | `context, meta, rows` — остатки по счетам организаций | `run_step2.log` |
| `report/stock/all` | — | `200` | `context, meta, rows` — остатки товаров, `meta.size=328` | `run_step2.log` |
| `report/stock/bystore` | — | `200` | `context, meta, rows` — остатки по складам, `meta.size=345` | `run_step2.log` |
| `report/turnover/all` | 2026-05-01…2026-06-01 | `200` | `context, meta, rows` — обороты по товарам, `meta.size=354` | `run_step2.log` |
| `report/dashboard/money` | — | `200` | `sales, orders, money` — сводка (текущий период дашборда МойСклад, не май-2026 явно) | `run_step2.log` |
| `report/dashboard/orders` | — | `200` | идентичный ответ `dashboard/money` — по факту один и тот же ресурс | `run_step2.log` |

## Дополнительные entity-API проверки (уровень (ii), для поверхностей без покрытия report-API)

| Endpoint | HTTP | Вердикт | Скрипт·лог |
|---|---|---|---|
| `entity/invoiceout?expand=agent,state` | `200` | `meta.size=4456` строк — оракул уровня (ii) для дебиторки (AR); нет отдельного bulk report-API эндпоинта задолженности (`report/counterparty/debt*` — оба пути 404) | `run_step2b.log` |
| `entity/purchaseorder?expand=agent,state` | `200` | `meta.size=211` строк — оракул уровня (ii) для «Закупки в пути»; нет report-API эндпоинта, специфичного для заказов в пути (`report/stock/*` покрывает текущие остатки, не заказы поставщику) | `run_step2c.log` |
| `entity/loss?expand=expenseItem&momentFrom=2026-05-01…` | `200` | `meta.size=128` строк за май-2026 — повторное подтверждение (канон уже в `02_ERP_CONTRACTS §семантика П&Л`/`ADR-006`), не новое открытие | `run_step2c.log` |

---

## Вердикты по поверхностям Шага 1 (свод)

| Поверхность BI (мart · страница LS) | Уровень эталона | Endpoint(ы) | Основание |
|---|---|---|---|
| `marts.sales_overview` (Инвестор, Операционка) | (i) подтверждён | `report/profit/byproduct`, `report/profit/bycounterparty` | живой `200`, поля прибыльности по товару/контрагенту за май-2026 |
| `marts.customer_invoices_ar` (Операционка) | (ii) подтверждён, (i) недоступен | `entity/invoiceout` | `report/counterparty/debt*` — оба варианта `404`; report-API не покрывает поверхность (нет bulk-эндпоинта задолженности) |
| `msklad_counterparty_returns` (Операционка, Трек A) | (i) частично / не подтверждён целиком | нет прямого эндпоинта возвратов | `report/profit/bysalesreturn` — `404`; возвраты в report-API не выделены отдельным отчётом, кандидат не найден среди проверенных путей |
| `marts.inventory_health` (Склад) | (i) подтверждён | `report/stock/all`, `report/stock/bystore` | живой `200`, остатки товаров/по складам |
| `marts.in_transit` (Склад, Закупки в пути) | (ii) подтверждён, (i) недоступен | `entity/purchaseorder` | нет report-API эндпоинта для заказов поставщику в пути; `report/stock/*` — про остатки, не про заказы |
| `marts.weight_flow` (Склад) | эталона нет ни на одном уровне | — | вес — наш расчётный KPI (`quantity × dim_products.weight`); МойСклад не публикует «весовой» отчёт ни в report-API, ни как страницу UI — нет стороны для сверки (см. «вне реестра» в `parity_registry.md`) |
| `marts.expenses` (Расходы, Трек B) | (ii) подтверждён (канон), (i) не применимо | `entity/paymentout`, `entity/cashout`, `entity/loss`, `entity/commissionreportin` | методология `ADR-006`/`ADR-026`, уже подтверждена 0,00 разницы (`ADR-033`, `fx_policy_expenses_2026-07-28.md`); report-API прямого «П&Л»-эндпоинта не имеет — ручная выгрузка П&Л из UI (уровень iii) остаётся действующим эталоном (`pnl_2026-05.md`) |

**Итог Шага 2:** report-API покрывает прибыльность/продажи (`profit/*`) и остатки (`stock/*`, `turnover/*`) на уровне (i); не покрывает дебиторскую задолженность bulk-отчётом, заказы поставщику в пути и возвраты покупателей отдельным отчётом (все три — `404`, определённый факт, не гэп авторизации); эквивалента «весовому» KPI нет вовсе. П&Л (расходы) как был, так и остаётся эталоном уровня (ii)/(iii) — report-API прямого П&Л-эндпоинта не документирует под проверенными путями.
