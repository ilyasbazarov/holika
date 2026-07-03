# PROJECT REFERENCE — BI-пайплайн МойСклад → BigQuery → Looker Studio

**Версия:** 6.0
**Дата:** 2026-06-25
**Предыдущая версия:** 5.0 (2026-06-24)
**Проект:** msklad-bi-prod (GCP)
**Клиент:** Дистрибьютор корейской косметики, Бишкек, Кыргызстан
**Рынки:** Дордой / Джунхай, 99% B2B опт
**Цель:** BI-система для оценки бизнеса перед инвестором

> **Как использовать:** загрузи этот файл в начало каждой сессии вместе с RUNBOOK_v8.md.
> Он содержит всё что нужно для хирургической диагностики и разработки без discovery-шагов.

## Итог сессии 2026-06-24 (сводный changelog v4.0 → v5.0)

Сессия началась с применения трёх дельт изменений (order_name/id+name mapping, Ghost Records, bq CLI/expand+limit/T-1 DQ стандарт — детали в RUNBOOK §19-24 и схемах ниже), затем переросла в полноценное расследование 4 несостыковок с МойСклад по обратной связи заказчика. Главный результат сессии — **найден и исправлен системный баг, занижавший выручку на ~43% и закупки минимум на треть.**

**Закрытые задачи:**
- **TD-CF-PAYMENTS-NAME, TD-DQ-REVISION** — CONTEXT GAP по `cf-finance` закрыт логом деплоя (имя, URL, ревизия, расписание)
- **TD-SEC-01** — подтверждён как баг (`cf-finance` с `--allow-unauthenticated`), в backlog P1
- **TD-RECON-01 (выручка май)** — ЗАКРЫТ. Корневая причина: отсутствие конвертации по курсу валюты документа в `fetch_demands.py`/`fetch_returns.py`/`fetch_purchases.py`. После фикса: 93 540 320,53 vs эталон 93 251 530,80 (99,7%)
- **TD-RECON-02 (по сотрудникам)** — ЗАКРЫТ автоматически вслед за TD-RECON-01, тот же mart/код

**Открытые задачи (передаются в следующую сессию):**
- **TD-RECON-03 (закупки «В пути»)** — после валютного фикса выросло с 1,2M до 68,9M, ориентир МойСклада 82+M, остаточный разрыв ~16%. Вторая причина не найдена — основной кандидат `window_days=90`, отсекающий старые ещё открытые заказы (длинный лидтайм из Кореи). Это задача СЛЕДУЮЩЕЙ сессии
- **TD-RECON-04 (платежи)** — код-ревью `cf-finance` на тот же валютный баг ещё не сделан
- **TD-FX-CONVERSION-01** — код-фикс подтверждён только для `cf-facts`; `cf-finance` не проверена
- **TD-PAYMENTS-RECOUNT** — пересчёт `fact_payments` после Ghost Records fix всё ещё не сделан

**Главные уроки сессии (см. также RUNBOOK §25-28 и правила 30-35 ниже):**
1. Реконсиляция с мастер-системой требует ground truth ИЗ мастер-системы, не из своих же таблиц (правило 34)
2. UI quick-select периода в МойСкладе ненадёжен — всегда проверять фактический диапазон в шапке отчёта/экспорта (кейс: "май" реально вернул май+июнь из-за таймзоны)
3. Мультивалютные документы — частая, неочевидная причина системной недооценки сумм; `price/100` без умножения на `rate.value` даёт до 90x недооценку
4. Code review может найти "недоделанный" фикс — переменная извлекается, но не используется (был кейс именно так в `fetch_purchases.py`)
5. Упавший деплой CF не блокирует прогон триггеров — они "успешно" выполнятся на старом коде; всегда проверять revision/updateTime перед триггерами
6. `mode=weekly` пишет в staging, не в core — нужен `mode=promote` отдельно
7. SQL-гигиена: `ROWS` — зарезервированное слово в BigQuery; `demand_id` нет в `core.fact_sales_profit` (только `transaction_id`); формат `bq query` для bash — одинарные кавычки снаружи, двойные для SQL-литералов внутри
8. Один пример не доказывает паттерн — систематический diff по всем строкам надёжнее единичного теста

---

## Итог сессии 2026-06-25 (сводный changelog v5.0 → v6.0)

Сессия продолжила работу с того места, где остановилась предыдущая: две задачи, переданные в backlog (TD-RECON-03 и TD-RECON-04), доведены до конца. По ходу обеих всплыли находки, не входившие в исходную формулировку задач — отдельно зафиксированы как новые TD-пункты, а не молча проигнорированы.

**Закрытые задачи:**
- **TD-RECON-03 (закупки «В пути»)** — ЗАКРЫТО. Гипотеза `window_days=90` опровергнута железно: построчная сверка 13/13 заказов «В пути» с МойСкладом дала diff=0,00. Реальная причина — `marts.in_transit` не успел пересобраться после валютного фикса в core (SQ ежедневно в 13:09 UTC, фикс прилетел в core в 22:01 UTC того же дня — обычный временной лаг между слоями, не сбой автоматизации; `sq_marts_in_transit` здоров, 0 FAILED за 10 дней). Ручной форс-ребилд → 104 877 706,09 vs МойСклад 104 877 706,26 (diff 0,17 KGS). Владелец подтвердил визуально на дашборде.
- **TD-RECON-04 (платежи, инфраструктура)** — ЗАКРЫТО. Найдены и устранены ДВА независимых дефекта `cf-finance`: (1) функция деплоена с `--timeout=300s`, но при каждом запуске тянет ВСЮ историю платежей без инкрементального окна — с ростом объёма стала упираться в таймаут на каждом ночном прогоне с 2026-06-19, `Scheduler` без ретраев (`maxRetryDuration=0s`) тихо это скрывал; исправлено редеплоем с `--timeout=1800s`. (2) После фикса таймаута — функция падала в HTTP 500 на необязательном шаге `trigger_marts()` (force-trigger `sq_marts_expenses`, `PermissionDenied` у `etl-sa`) **уже ПОСЛЕ** успешного `MERGE` — данные не терялись, но HTTP-ответ был ошибочным; исправлено через `try/except` вокруг этого вызова. Оба фикса подтверждены живым успешным прогоном (HTTP 200, свежие `_loaded_at`, без дублей и без гонки между параллельными вызовами).

**Новые задачи, заведённые по итогам сессии (не были в исходной формулировке):**
- **TD-PNL-RECON-01** *(новая)* — 4 статьи П&Л за май (`Списания`, `Комиссия`, `Неразнесенное списание`, `Обучение`, ~85,6% остаточного разрыва ~3,6M KGS) полностью отсутствуют в `fact_payments` ДАЖЕ на свежих данных (опровергнута гипотеза заморозки — свежая перезагрузка дала байт-в-байт идентичный результат). Минимум 3 из 4 статей реально встречаются в документах **списания** (`entity/loss`), которые `cf-finance` вообще не запрашивает (запрашивает только `paymentout`/`cashout`). Но прямое сложение `payments + loss` не сходится 1:1 с цифрами П&Л МойСклада ни по одной из проверенных статей (расхождения от -31% до +9x) — методология агрегации П&Л осталась неустановленной. «Комиссия» и «Обучение» не найдены вообще ни в одном из проверенных источников
- **TD-CF-FINANCE-SCOPE-01** *(новая)* — `cf-finance` делает полный re-fetch всей истории `paymentout`+`cashout` при КАЖДОМ запуске (подтверждено по коду, без date-фильтра). Текущий обход (`--timeout=1800s`) временный — при дальнейшем росте объёма данных таймаут повторится. Нужна инкрементальная загрузка (по аналогии с `window_days` в `cf-facts`)
- **TD-CF-FINANCE-PERMS-01** *(новая, не блокирует)* — `etl-sa` не имеет прав на BigQuery Data Transfer API для `sq_marts_expenses` (`PermissionDenied` на `start_manual_transfer_runs`). Сейчас падение поглощается `try/except`. Решить: выдать права ИЛИ убрать вызов `trigger_marts()` целиком — mart обновляется по собственному расписанию (тот же урок, что и в TD-RECON-03 с `marts.in_transit`)

**Обновлены по факту новых данных:**
- **TD-FX-CONVERSION-01** — код-ревью `cf-finance` на валютный баг сделан. Системного `÷100 без ×rate` паттерна в платежах НЕ найдено; реальная причина расхождения — другая (см. TD-RECON-04/TD-PNL-RECON-01)
- **TD-PAYMENTS-RECOUNT** — пересчёт сделан на свежих данных (после фикса таймаута): 4732 строки в `fact_payments` (было 4548 на момент v3.0). «Неразнесенное списание» = 0 строк в мае при свежей полной перезагрузке — открытый вопрос перенесён в TD-PNL-RECON-01

**Главные уроки сессии (детали — правила 36-42 ниже в разделе 7, разворот по симптомам — RUNBOOK §29-33):**
1. Прежде чем считать SQ/CF сломанной — сравнить timestamp последнего обновления ИСТОЧНИКА и ПОТРЕБИТЕЛЯ (core vs mart, core vs CF-триггер) — расхождение может быть обычным лагом расписаний, не сбоем
2. **Traceback в Python ВСЕГДА нормализует отображаемый отступ строки (обычно к 4 пробелам) независимо от реального отступа в файле.** Нельзя патчить код, опираясь на отступ из traceback — нужно читать сам файл
3. Патч по подстроке небезопасен и неидемпотентен, если результат замены содержит исходный паттерн как часть себя (`"    foo()"` — подстрока `"        foo()"`) — патчить по точным номерам строк или полным строкам целиком
4. Долгие (>1-2 мин) ручные HTTP-вызовы CF из Cloud Shell — обрывают видимый вывод терминала, хотя сервер продолжает работать. Использовать `nohup ... & disown`, проверять результат через слой данных (BQ `_loaded_at`), не через терминал
5. Веб-терминал Cloud Shell ненадёжен для вставки многострочного кода (heredoc или иначе) — использовать Upload-file или одну физическую строку без вложенных переносов
6. Реконсиляция по конкретному полю, не только по периоду/масштабу: «Сумма» и «В ожидании» в МойСкладе — разные числа для одного документа; сравнивать нужно концептуально то же поле, что считает пайплайн
7. П&Л-категории расходов МойСклада не ограничены платёжными документами — статья может частично или полностью происходить из документов списания (`entity/loss`); любая будущая сверка payments должна это учитывать

---

## 1. СЕРВИСЫ

### Cloud Functions (region: asia-east1)

| CF | URL | Ревизия | Ответственность |
|---|---|---|---|
| cf-dim | https://cf-dim-xw5u2boozq-de.a.run.app | 2026-06-03 | Загрузка dim_products (incl. weight), dim_counterparties (incl. country), dim_employees, dim_metadata_mappings |
| cf-facts | https://cf-facts-xw5u2boozq-de.a.run.app | 2026-06-03 | Загрузка fact_sales_profit (incl. sales_channel, project), fact_purchases (incl. order_name, 2026-06-24) |
| cf-fx | https://cf-fx-xw5u2boozq-de.a.run.app | 2026-06-03 | Загрузка dim_fx_rates из Bakai Bank OpenBanking API (НБКР officialRates) |
| cf-inventory | https://cf-inventory-xw5u2boozq-de.a.run.app | 00003-vuf | Ежедневный снэпшот fact_inventory в 03:00 KGT |
| cf-dq | https://cf-dq-xw5u2boozq-de.a.run.app | 00006-lac | DQ Gate: 6 чеков перед promote |
| **cf-finance** | **https://cf-finance-xw5u2boozq-de.a.run.app** | **cf-finance-00006-piv (деплой 2026-06-25)** | **Загрузка fact_payments (paymentout+cashout). Заменяет standalone `load_payments.py`. ⚠️ Trigger: `--allow-unauthenticated` (см. TD-SEC-01). ⚠️ Полный re-fetch без инкрементального окна (см. TD-CF-FINANCE-SCOPE-01)** |

**Вызов CF вручную (шаблон):**
```bash
curl -X POST https://<CF_URL> \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $(gcloud auth print-identity-token)" \
  -d '{"mode": "...", "window_days": 90}'
```

### cf-facts — режимы (mode)

| mode | window_days | Что делает |
|---|---|---|
| hourly | 7 (default) | Загружает staging из МойСклад за последние 7 дней |
| promote | 7 или 90 | MERGE staging → core.fact_sales_profit без DQ check |
| weekly | 90 | Полный reload 90 дней (для FIFO пересчёта после поставок) |
| returns | 730 | TRUNCATE + reload fact_returns за 2 года |
| purchases | 90 | MERGE fact_purchases за 90 дней |

### Standalone ETL-скрипты (CloudShell, не CF)

| Скрипт | Расположение | Что делает | Периодичность |
|---|---|---|---|
| load_invoices.py | /tmp/load_invoices.py | MERGE invoiceout → core.fact_customer_invoices | Вручную (при необходимости) |
| ~~load_payments.py~~ | ~~/tmp/load_payments.py~~ | **✅ МИГРИРОВАНО 2026-06-18** в `cf-finance` (gen2) + Cloud Scheduler `finance-daily-update` (`03:00 Asia/Bishkek`, cron `0 3 * * *`). MERGE paymentout+cashout → core.fact_payments | Ежедневно 03:00 KGT (CF) |

**⚠️ Находка (по логу деплоя, не в дельте):** `cf-finance` задеплоена с `--trigger-http --allow-unauthenticated` — в отличие от остальных CF проекта, которые вызываются с `Authorization: Bearer $(gcloud auth print-identity-token)`. Функция содержит финансовые данные и доступна по URL без аутентификации. Стоит сознательно решить — это намеренное решение (например, вызов из Scheduler не настроен на OIDC) или упущение при копипасте деплой-команды. См. TD-SEC-01.

**⚠️ Перед запуском standalone скриптов:** `export TOKEN=$(gcloud secrets versions access latest --secret="msklad-token" --project="msklad-bi-prod")`

**cf-finance (конфигурация, актуальная на 2026-06-25):**
```bash
gcloud functions deploy cf-finance \
  --gen2 --runtime=python312 --region=asia-east1 \
  --source=. --entry-point=main \
  --trigger-http --allow-unauthenticated \
  --service-account=etl-sa@msklad-bi-prod.iam.gserviceaccount.com \
  --memory=512MB --timeout=1800s \
  --set-secrets="MSKLAD_TOKEN=msklad-token:latest"
```
- Исходники: `/home/ilyasbazarov4/cf-finance` (Cloud Shell persistent disk)
- Revision: `cf-finance-00006-piv` (история: 00001-wiv первый деплой 2026-06-18 → 00005-wob фикс таймаута 2026-06-25 → 00006-piv фикс `trigger_marts()` 2026-06-25)
- URI (Cloud Run native): `https://cf-finance-xw5u2boozq-de.a.run.app`
- Legacy URL: `https://asia-east1-msklad-bi-prod.cloudfunctions.net/cf-finance`
- Cloud Scheduler: `finance-daily-update`, `0 3 * * *`, `Asia/Bishkek`, HTTP POST на URI выше. **⚠️ `retryConfig.maxRetryDuration=0s` — ретраев НЕТ.** Падение Scheduler тихо проглатывается (`status.code=2/UNKNOWN`), без алерта на сам факт неуспеха — алерт приходит только от мониторинга 5xx на стороне Cloud Run, не от Scheduler
- **⚠️ (2026-06-25, КРИТИЧНО) `run_etl()` запрашивает `entity/paymentout` и `entity/cashout` ПОЛНОСТЬЮ, без date-фильтра, при КАЖДОМ запуске** (см. `main.py`, цикл `for entity_type in ["paymentout", "cashout"]`). Это не инкрементальная загрузка — полный проход занимает ~12-13 минут на объёме ~6000+ записей. Именно это стало причиной таймаута 2026-06-25 (см. TD-CF-FINANCE-SCOPE-01) — `--timeout=1800s` временно решает проблему, но не масштабируется
- **⚠️ (2026-06-25) `run_etl()` после `MERGE`+`DELETE` вызывает `trigger_marts()` — форс-триггер `sq_marts_expenses` через BigQuery Data Transfer API.** `etl-sa` не имеет прав на это (`PermissionDenied`, см. TD-CF-FINANCE-PERMS-01). Вызов обёрнут в `try/except` (2026-06-25) — падение не блокирует ответ функции, но сам форс-триггер всё равно никогда не срабатывает. `sq_marts_expenses` обновляется по собственному ежедневному расписанию независимо от этого вызова

**Канонический порядок выполнения `run_etl()` (подтверждено логами, 2026-06-25):**
1. Полная выгрузка `paymentout`+`cashout` из МойСклада (без date-фильтра)
2. `Loading N records to STG...` — `WRITE_TRUNCATE` в `fact_payments_stg`
3. `Running MERGE...` — `MERGE` staging → `core.fact_payments` по `payment_id`
4. `Cleaning up excluded system expenses (ghosts removal)...` — `DELETE` по `EXCLUDE_EXPENSE_IDS`
5. `Triggering scheduled query via API...` — `trigger_marts()`, может упасть (см. выше), **на шаги 1-4 это не влияет** — они уже закоммичены к этому моменту

### Конфигурация CF (config.py — актуальные значения)

**Общие для всех CF:**
```python
GCP_PROJECT  = "msklad-bi-prod"
GCS_RAW      = "msklad-raw-msklad-bi-prod"
MSKLAD_BASE  = "https://api.moysklad.ru/api/remap/1.2"
MSKLAD_RPS   = 4
PAGE_SIZE    = 1000
SECRET_TOKEN = "msklad-token"
# 🟡 (2026-06-24) Принадлежит сотруднику стороннего приложения "Финтабло"
#     (fintablo@koreagloballlc), не выделенному ETL service account — см. TD-AUTH-01 (P2, hygiene).
#     НЕ является причиной майского разрыва по выручке (проверено и опровергнуто, см. TD-RECON-01).

# ⚠️ (2026-06-18, cf-finance) В цикле пагинации ОБЯЗАТЕЛЕН time.sleep(0.25) — иначе 429/5xx от МойСклад
# ⚠️ (2026-06-18, cf-finance) При expand= (например expand=expenseItem) limit НЕ ДОЛЖЕН превышать 100 —
#     иначе API молча игнорирует expand и возвращает NULL вместо вложенного объекта
# ⚠️ (дата не подтверждена, см. RUNBOOK §24) timeout в _api_get / requests-обёртке = 90 (не 30) для тяжёлых эндпоинтов
#     (например entity/purchaseorder/{id}/positions). tenacity-ретраи не спасают от низкого timeout
# ⚠️ (2026-06-18, cf-finance) В среде CF (gen2/Cloud Run) НЕТ утилиты `bq`. subprocess.run(["bq", ...]) → FileNotFoundError.
#     Только google-cloud-bigquery / google-cloud-bigquery-datatransfer
```

**cf-facts (дополнительно):**
```python
HOURLY_WINDOW_DAYS  = 7
WEEKLY_WINDOW_DAYS  = 90
STG_FACT_SALES      = "msklad-bi-prod.stg_msklad.fact_sales_staging"
CORE_FACT_SALES     = "msklad-bi-prod.core.fact_sales_profit"
CORE_BYVARIANT_BCK  = "msklad-bi-prod.core.fact_sales_profit_byvariant_backup"
CORE_FACT_PURCHASES = "msklad-bi-prod.core.fact_purchases"
# ⚠️ (2026-06-24) Парсер purchaseorder теперь обязательно извлекает order_name = order.get("name")
#     помимо purchase_order_id — см. правило id+name в разделе 7

PURCHASE_ORDER_STATES = {
    "491d6da5-8b37-11ef-0a80-0762000253a8": "В пути",
    "491d62b6-8b37-11ef-0a80-0762000253a7": "Прибыл",
    "87b7a192-349f-11f1-0a80-1a0f000384c2": "Прибыл частично",
    "87b7a5e5-349f-11f1-0a80-1a0f000384c3": "Отменен",
}
IN_TRANSIT_STATUS_ID = "491d6da5-8b37-11ef-0a80-0762000253a8"  # "В пути"
```

**cf-fx (после миграции 2026-06-03):**
```python
# Источник: Bakai Bank OpenBanking API → officialRates[USD].rate (курс НБКР)
BAKAI_FX_URL = "https://openbanking-api.bakai.kg/api/Directory/GetRateDirectory"
BAKAI_SECRET = "bakai-fx-token"  # Secret Manager, JWT-токен, Bearer auth
# Использует MERGE по дате (TD-CF-FX закрыт — дублей нет)
# Graceful degradation: 401 → forward-fill + лог "update bakai-fx-token in Secret Manager"
# GCS архив: fx-rates/bakai_{YYYY-MM-DD}.json
# ⚠️ TTL токена неизвестен. При истечении → см. RUNBOOK_v8 §17
```

**cf-dq (актуальные пороги, ревизия 00006-lac — ⚠️ ревизия после T-1-фикса не зафиксирована в дельте, уточнить):**
```python
DQ_DRIFT_THRESHOLD         = 0.10
DQ_DRIFT_WEEKEND_THRESHOLD = 0.03
DQ_FRESHNESS_MAX_DAYS      = 3
DQ_CURRENCY_MAX_AVG_REV    = 10_000_000
# ⚠️ (2026-06-24) Стандарт T-1: drift_check сравнивает выручку T-1 (вчера) с MA7 за период T-8…T-2.
#     T-0 (текущий день) использовать ЗАПРЕЩЕНО — неполный день даёт ложные срабатывания.
```

---

## 2. WORKFLOW DAG

**Имя:** msklad-pipeline-hourly
**Расписание:** каждый час
**Порядок:**
```
step_dim → step_fx → step_facts(hourly) → step_dq → [check_dq] → step_promote(window=7) → step_purchases(window=90, NON-BLOCKING)
```

**Запуск вручную:**
```bash
gcloud workflows run msklad-pipeline-hourly --location=asia-east1 \
  --format="table(name.basename(),state)"
```

---

## 3. SCHEDULED QUERIES

| SQ Name | Config ID | Расписание | Стратегия |
|---|---|---|---|
| sq_audit_dim_products_snapshot | 69fc93d1-0000-2d64-bdd1-30fd381336b4 | ежедневно | INSERT |
| sq_audit_dim_counterparties_snapshot | 69fc9c75-0000-2ab4-91b3-883d24f4db64 | ежедневно | INSERT |
| sq_audit_dim_employees_snapshot | 69fc9d6e-0000-2ab4-91b3-883d24f4db64 | ежедневно | INSERT |
| sq_marts_inventory_health | 69fd92d9-0000-2372-ad37-582429aca3ec | ежедневно 05:00 UTC | CREATE OR REPLACE |
| sq_marts_sales_overview | 69ff34b4-0000-2b2b-a390-14c14ef7af10 | каждые 2 часа | CREATE OR REPLACE |
| sq_marts_gmroi_by_folder | 6a004e88-0000-2e7d-bf20-9898fbb40f95 | ежедневно | CREATE OR REPLACE |
| sq_marts_gmroi | 6a006664-0000-2739-86f5-7474463a7ac5 | ежедневно | CREATE OR REPLACE |
| sq_marts_abc_xyz | 6a020b2c-0000-2dd6-96d2-883d24f52bd4 | ежедневно | CREATE OR REPLACE |
| sq_marts_in_transit | 6a0aa537-0000-260f-b391-d43a2cee6b87 | ежедневно 13:09 UTC *(уточнено 2026-06-25 — было общее "ежедневно", см. М-39)* | CREATE OR REPLACE |
| sq_marts_supplier_price_history | 6a0b0f25-0000-2893-be44-d43a2cc31f97 | ежедневно | CREATE OR REPLACE |
| sq_marts_weight_flow | 6a1f9418-0000-276f-a1e4-d4f547ee7418 | ежедневно | CREATE OR REPLACE |
| **sq_marts_customer_invoices_ar** | **6a23f3ea-0000-2952-853d-582429be7ecc** | **ежедневно** | **CREATE OR REPLACE** |
| **sq_marts_expenses** | **6a22a243-0000-20fd-a458-883d24f4cad4** | **ежедневно** | **CREATE OR REPLACE — ⚠️ `cf-finance` пытается форсировать этот SQ после каждого MERGE через `trigger_marts()`, но `etl-sa` не имеет прав (см. TD-CF-FINANCE-PERMS-01); сам SQ при этом работает штатно по своему расписанию** |

**Путь:** `projects/420804682491/locations/asia-east1/transferConfigs/{Config ID}`

**Принудительный запуск:**
```bash
bq mk --transfer_run \
  --run_time=$(date -u +%Y-%m-%dT%H:%M:%SZ) \
  projects/420804682491/locations/asia-east1/transferConfigs/{CONFIG_ID}
```

**Патч SQL Scheduled Query (ТОЛЬКО через Python, не heredoc):**
```python
import subprocess, json
NEW_SQL = """..."""
subprocess.run(["bq", "update", "--transfer_config",
  "--params", json.dumps({"query": NEW_SQL}),
  "projects/420804682491/locations/asia-east1/transferConfigs/{CONFIG_ID}"])
```

---

## 4. СХЕМЫ ТАБЛИЦ

### 4.1 stg_msklad (staging, TTL 14 дней)

#### fact_sales_staging
| Колонка | Тип | Описание |
|---|---|---|
| run_id | STRING | ID запуска CF |
| demand_id | STRING | ID отгрузки в МойСкладе |
| position_id | STRING | ID позиции отгрузки |
| **transaction_date_raw** | **STRING** | **⚠️ СТРОКА формата 'YYYY-MM-DD HH:MM:SS.mmm'. Использовать DATE(transaction_date_raw)** |
| product_id | STRING | FK → core.dim_products |
| agent_id | STRING | FK → core.dim_counterparties |
| quantity | FLOAT64 | Количество |
| price_kgs | FLOAT64 | Цена в KGS |
| discount | FLOAT64 | Скидка %. NULL = 0% |
| revenue_kgs | FLOAT64 | Выручка в KGS |
| entity_type | STRING | 'product' или 'variant' |
| sales_channel_id | STRING | UUID канала продаж из МойСклада |
| sales_channel_name | STRING | Название канала |
| project_id | STRING | UUID проекта из МойСклада |
| project_name | STRING | Название проекта |
| _loaded_at | TIMESTAMP | Время загрузки |

### 4.2 core

#### core.fact_sales_profit
| Колонка | Тип | Описание |
|---|---|---|
| transaction_id | STRING | MD5(demand_id + position_id) — суррогатный ключ |
| transaction_date | DATE | Дата транзакции в Asia/Bishkek |
| product_id | STRING | FK → dim_products |
| entity_type | STRING | product/variant/bundle |
| agent_id | STRING | FK → dim_counterparties |
| sell_quantity | FLOAT64 | Продано штук |
| return_quantity | FLOAT64 | Возвращено штук |
| sell_sum_kgs | FLOAT64 | Выручка KGS |
| return_sum_kgs | FLOAT64 | Сумма возвратов KGS |
| revenue_kgs | FLOAT64 | Нетто выручка KGS |
| cogs_kgs | FLOAT64 | Себестоимость KGS (FIFO, NULL если неизвестна) |
| margin_kgs | FLOAT64 | Маржа KGS (NULL если нет COGS) |
| revenue_usd | FLOAT64 | Выручка USD |
| cogs_usd | FLOAT64 | Себестоимость USD |
| margin_usd | FLOAT64 | Маржа USD |
| discount | FLOAT64 | Скидка % |
| sales_channel_id | STRING | UUID канала продаж из МойСклада |
| sales_channel_name | STRING | Название канала (COALESCE → 'Не указан') |
| project_id | STRING | UUID проекта из МойСклада |
| project_name | STRING | Название проекта (COALESCE → 'Не указан') |
| _loaded_at | TIMESTAMP | — |

#### core.fact_purchases *(схема восстановлена по дельте от 2026-06-24 — поля ниже подтверждены SQL-кодом marts.in_transit; таблица не была явно задокументирована в v3.0)*
| Колонка | Тип | Описание |
|---|---|---|
| purchase_order_id | STRING | UUID заказа поставщику — для JOIN/MERGE |
| **order_name** | **STRING** | **🆕 (2026-06-24) Человекочитаемый номер заказа (`order.get("name")`) — основной Dimension для BI вместо UUID** |
| position_id | STRING | UUID позиции заказа |
| order_date | DATE | Дата создания заказа |
| planned_delivery_date | DATE | Плановая дата поставки (может быть NULL) |
| product_id | STRING | FK → dim_products |
| supplier_id | STRING | FK → dim_counterparties (agent_id) |
| status_id | STRING | UUID статуса заказа (см. раздел 6) |
| status_name | STRING | Денормализованное название статуса |
| quantity_ordered | FLOAT64 | Заказано штук |
| quantity_shipped | FLOAT64 | Отгружено поставщиком штук |
| quantity_in_transit | FLOAT64 | В пути штук |
| price_kgs | FLOAT64 | Цена в KGS |
| in_transit_sum_kgs | FLOAT64 | Сумма в пути, KGS |
| _loaded_at | TIMESTAMP | Время загрузки (по аналогии с другими fact_*, не подтверждено отдельно в дельте) |

**⚠️ Поля выше — не исчерпывающий список,** только то, что встречается в актуальном SQL `marts.in_transit` (см. 4.3). Если в коде CF есть дополнительные поля — дополнить при следующей сессии.

#### core.dim_products
| Колонка | Тип | Описание |
|---|---|---|
| product_id | STRING | UUID товара в МойСкладе |
| name | STRING | Название |
| article | STRING | Артикул |
| product_folder | STRING | Бренд |
| parent_product_id | STRING | UUID родителя для variant |
| entity_type | STRING | product/variant/bundle |
| created | DATE | Дата создания |
| shelf_life | TIMESTAMP | Срок годности (кастомное поле) |
| qty_per_box | FLOAT64 | Количество в упаковке |
| is_exclusive | BOOL | Эксклюзивный товар |
| is_sunscreen | BOOL | Солнцезащитный |
| updated_at | TIMESTAMP | Дата обновления в МойСкладе |
| **weight** | **FLOAT64** | **Вес единицы в кг. Покрытие ~32.6% (1463/4492 SKU). Растёт по мере заполнения** |
| _loaded_at | TIMESTAMP | — |

#### core.dim_counterparties
| Колонка | Тип | Описание |
|---|---|---|
| agent_id | STRING | UUID контрагента |
| name | STRING | Наименование |
| owner_employee_id | STRING | FK → dim_employees (текущий менеджер) |
| owner_employee_skey | STRING | SCD2 суррогатный ключ |
| **country** | **STRING** | **Страна контрагента (кастомное поле UUID: 6d6cca1e-ed85-11f0-0a80-0b1a00a4547c)** |
| scd2_valid_from | TIMESTAMP | — |
| scd2_valid_to | TIMESTAMP | — |
| scd2_is_current | BOOL | **JOIN всегда с AND scd2_is_current = TRUE** |
| _loaded_at | TIMESTAMP | — |

#### core.dim_fx_rates
| Колонка | Тип | Описание |
|---|---|---|
| date | DATE | Дата курса |
| rate_kgs_per_usd | FLOAT64 | KGS за 1 USD (официальный курс НБКР) |

**Источник с 2026-06-03:** Bakai Bank OpenBanking API → `officialRates[currencySymbol=USD].rate`

#### core.fact_customer_invoices *(новая, 2026-06-05)*
| Колонка | Тип | Описание |
|---|---|---|
| invoice_id | STRING NOT NULL | UUID счёта покупателю (invoiceout) |
| invoice_name | STRING | Номер счёта (человекочитаемый) |
| moment | DATE | Дата выставления счёта |
| agent_id | STRING | UUID покупателя → JOIN dim_counterparties |
| agent_name | STRING | Имя покупателя (денормализовано) |
| state_id | STRING | UUID статуса оплаты |
| state_name | STRING | Статус оплаты (Оплачено / Ожидает оплату / Частично оплачен / ...) |
| sum_kgs | FLOAT64 | Сумма счёта в KGS |
| payed_sum_kgs | FLOAT64 | Оплаченная сумма в KGS |
| unpaid_sum_kgs | FLOAT64 | Неоплаченный остаток (sum - payedSum) |
| payment_planned | DATE | Плановая дата оплаты (paymentPlannedMoment) |
| sales_channel_id | STRING | UUID канала продаж |
| sales_channel_name | STRING | Название канала |
| _loaded_at | TIMESTAMP | — |

**Источник МойСклад:** `GET /entity/invoiceout?expand=agent,state`
**Загрузка:** standalone скрипт `/tmp/load_invoices.py` (MERGE по invoice_id)
**Всего записей:** 4058

#### core.fact_payments *(новая, 2026-06-05)*
| Колонка | Тип | Описание |
|---|---|---|
| payment_id | STRING NOT NULL | UUID платежа |
| payment_name | STRING | Номер документа |
| payment_type | STRING | 'paymentout' или 'cashout' |
| moment | DATE | Дата платежа |
| expense_item_id | STRING | UUID статьи расходов |
| expense_item_name | STRING | Название статьи расходов (Зарплата, Аренда, ...) |
| agent_id | STRING | UUID получателя платежа |
| agent_name | STRING | Имя получателя |
| project_id | STRING | UUID проекта МойСклада |
| project_name | STRING | Название проекта |
| sales_channel_id | STRING | UUID канала продаж |
| sales_channel_name | STRING | Название канала |
| payment_purpose | STRING | Назначение платежа (свободный текст) |
| sum_kgs | FLOAT64 | Сумма в KGS |
| _loaded_at | TIMESTAMP | — |

**Источники МойСклад:** `GET /entity/paymentout` + `GET /entity/cashout` (expand=agent,expenseItem)
**Загрузка:** Cloud Function `cf-finance` (gen2) + Cloud Scheduler `finance-daily-update` (`03:00 Asia/Bishkek` ежедневно) *(мигрировано 2026-06-18, было — standalone `/tmp/load_payments.py`, см. раздел 1)*. MERGE по payment_id.

**Фильтрация при загрузке (исправлено 2026-06-18 — Ghost Records fix):**
- ✅ `applicable=False` (черновики) — фильтруются на уровне Python при выгрузке, как и раньше. Это легитимный фильтр, к Ghost Records не относится.
- ❌ **Статьи-перемещения через `EXCLUDE_EXPENSE_IDS` на уровне Python — БОЛЬШЕ НЕ ИСПОЛЬЗУЕТСЯ.** Старый подход вызывал Ghost Records: если документ изначально был без статьи ("Неразнесенное списание"), попадал в BQ; когда клиент позже проставлял статью-исключение (например "Перемещение"), скрипт перестаёт его выгружать — `MERGE` не видит обновления, и Ghost-запись со старым статусом зависает навечно.
- ✅ **Новый подход:** выгружаются ВСЕ платежи без исключений по статье. Системные статьи вычищаются `DELETE` в BigQuery **после** `MERGE`:
```sql
DELETE FROM `msklad-bi-prod.core.fact_payments`
WHERE expense_item_id IN ('24c0e914-2d8c-11f1-0a80-11b0000c7043', ...)
-- полный список — см. EXCLUDE_EXPENSE_IDS в коде cf-finance
```

**Всего записей:** 4732 (на 2026-06-25, после фикса таймаута и полной свежей перезагрузки `cf-finance`; было 4548 в v3.0, до фикса Ghost Records). Стабильно на двух последовательных успешных прогонах подряд (без дублей — `MERGE` по `payment_id` работает корректно).

**⚠️ `Неразнесенное списание`** — на 2026-06-25 показывает **0 строк за май** даже на свежей, только что перезагруженной с нуля выгрузке (опровергнута гипотеза, что причина — устаревшие данные/заморозка пайплайна, см. TD-PAYMENTS-RECOUNT). Минимум часть этой и трёх других статей П&Л (`Списания`, `Комиссия`, `Обучение`) физически живёт не в `paymentout`/`cashout`, а в документах списания (`entity/loss`), которые `cf-finance` не запрашивает в принципе — см. **TD-PNL-RECON-01**. Прямая арифметика `entity/loss` тоже не сходится 1:1 с П&Л МойСклада — методология агрегации не установлена.

**Контрольные цифры П&Л МойСклад за май 2026 (ground truth для TD-PNL-RECON-01, зафиксировано 2026-06-25):**
| Показатель | Сумма, KGS |
|---|---|
| Операционные расходы (полная строка П&Л) | 82 679 650,44 |
| из них «Перемещение исходящий» (легитимно исключено из ETL) | 73 324 305,91 |
| Налоги и сборы (отдельная строка П&Л, ПОСЛЕ «Операционная прибыль» — не входит в строку выше) | 1 776 959,36 |
| Операционные расходы минус «Перемещение», плюс Налоги (= сопоставимо с `fact_payments`) | 11 132 303,89 |
| `fact_payments` май (на момент проверки, после фикса таймаута) | 7 492 843,26 |
| **Разница (необъяснённый разрыв)** | **3 639 460,63 (~33%)** |
| из них: 4 статьи, полностью отсутствующие в `fact_payments` | 3 115 805,82 (85,6% разрыва) |
| — Списания | 45 788,94 |
| — Комиссия | 1 775 754,88 |
| — Неразнесенное списание | 1 260 262,00 |
| — Обучение | 34 000,00 |
| Остаток разрыва (размазан по статьям в обе стороны, не списан на одну причину) | 523 654,81 (14,4% разрыва) |

### 4.3 marts

#### marts.sales_overview
Расписание: каждые 2 часа | CREATE OR REPLACE

Ключевые поля:
- `country` — COALESCE(c.country, 'Не указана') из dim_counterparties
- `manager_name`, `manager_position` из dim_employees
- `sales_channel_name` — COALESCE(f.sales_channel_name, 'Не указан')
- `project_name` — COALESCE(f.project_name, 'Не указан')
- `return_sum_kgs`, `net_revenue_kgs` из LEFT JOIN fact_returns
- `is_cogs_missing`, `is_agent_missing` — флаги DQ

#### marts.inventory_health
| Поле | Описание |
|---|---|
| coverage_days_90d_calendar | Покрытие в днях (calendar ADT — для B2B) |
| coverage_days_true_adt | Покрытие в днях (true ADT — операционный) |
| is_low_stock, is_oos, is_toxic | Флаги состояния |

#### marts.in_transit *(обновлено 2026-06-24 — добавлен order_name)*
| Поле | Описание |
|---|---|
| **order_name** | **🆕 Человекочитаемый номер заказа — основной Dimension в LS (заменяет purchase_order_id на дашборде)** |
| purchase_order_id | ID заказа поставщику (теперь technical key, не для вывода в LS) |
| position_id | ID позиции заказа |
| days_until_delivery | Отрицательное = просрочено |
| is_overdue | planned < TODAY AND planned IS NOT NULL |
| product_name, product_folder | Денормализовано из dim_products |
| supplier_name | Денормализовано из dim_counterparties (JOIN AND scd2_is_current = TRUE) |
| status_name | Статус заказа |
| quantity_ordered, quantity_shipped, quantity_in_transit | Количества |
| in_transit_sum_kgs, in_transit_sum_usd | Суммы в пути |
| fx_rate_used | Курс FX, использованный при конвертации |

**Канонический SQL (актуальный, 2026-06-24):**
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

**Патч применён через:** `bq update --transfer_config` (Python, не heredoc) на `sq_marts_in_transit` (Config ID: `6a0aa537-0000-260f-b391-d43a2cee6b87`).

#### marts.supplier_price_history
| Поле | Описание |
|---|---|
| price_kgs, price_usd | Закупочная цена в KGS и USD |
| supplier_name, product_folder | Денормализовано |

#### marts.weight_flow *(2026-06-03)*
SQ: 6a1f9418-0000-276f-a1e4-d4f547ee7418

| Колонка | Тип | Описание |
|---|---|---|
| flow_date | DATE | Дата операции |
| week_start | DATE | Начало недели (WEEK SATURDAY) |
| month_start | DATE | Начало месяца |
| flow_direction | STRING | 'inbound' (приём) / 'outbound' (отгрузка) |
| weight_kg | FLOAT64 | Суммарный вес в кг |
| positions_total | INT64 | Всего позиций |
| positions_with_weight | INT64 | Позиций с weight > 0 в dim_products |
| weight_coverage_pct | FLOAT64 | % позиций с заполненным весом |

#### marts.customer_invoices_ar *(новый, 2026-06-05)*
SQ: 6a23f3ea-0000-2952-853d-582429be7ecc | ежедневно | CREATE OR REPLACE

| Колонка | Тип | Описание |
|---|---|---|
| agent_id | STRING | UUID покупателя |
| agent_name | STRING | Имя покупателя |
| country | STRING | Страна (из dim_counterparties) |
| state_name | STRING | Статус оплаты |
| state_id | STRING | UUID статуса |
| invoice_count | INT64 | Количество счетов |
| total_invoiced_kgs | FLOAT64 | Выставлено всего, KGS |
| total_paid_kgs | FLOAT64 | Оплачено, KGS |
| total_unpaid_kgs | FLOAT64 | Не оплачено, KGS |
| earliest_invoice_date | DATE | Дата самого раннего счёта |
| latest_invoice_date | DATE | Дата последнего счёта |
| overdue_count | INT64 | Счетов с просроченной плановой датой оплаты |

**Назначение:** Дебиторская задолженность (AR) — график на странице «Операционка»
**LS источник:** `msklad_customer_invoices_ar` (Custom Query, без date range параметров — snapshot)

#### marts.expenses *(новый, 2026-06-05)*
SQ: 6a22a243-0000-20fd-a458-883d24f4cad4 | ежедневно | CREATE OR REPLACE

| Колонка | Тип | Описание |
|---|---|---|
| moment | DATE | Дата платежа |
| month_start | DATE | Начало месяца |
| week_start | DATE | Начало недели (WEEK SATURDAY) |
| year_num | INT64 | Год |
| year_month | STRING | 'YYYY-MM' — для группировки по месяцу |
| payment_type | STRING | 'paymentout' / 'cashout' |
| expense_item_id | STRING | UUID статьи расходов |
| expense_item_name | STRING | Название статьи расходов |
| agent_id | STRING | UUID получателя |
| agent_name | STRING | Имя получателя |
| project_id | STRING | UUID проекта |
| project_name | STRING | Название проекта |
| sales_channel_id | STRING | UUID канала |
| sales_channel_name | STRING | Название канала |
| payment_count | INT64 | Количество платежей |
| total_sum_kgs | FLOAT64 | Сумма в KGS |
| total_sum_usd | FLOAT64 | Сумма в USD (по последнему курсу FX) |

**Назначение:** Страница «Расходы» (Burn Rate) для владельцев/инвесторов
**LS источник:** `msklad_expenses` (Custom Query, с date range на `moment`)

### 4.4 marts.abc_xyz
| Колонка | Тип | Описание |
|---|---|---|
| abc_class | STRING | A≤80%, B≤95%, C>95% кумулятивной выручки |
| xyz_class | STRING | X≤0.5, Y≤1.0, Z>1.0 CoV |
| abc_xyz | STRING | Конкатенация: AX, AY, BX... |

**Распределение (актуальное):** X=39, Y=148, Z=439 (626 total). A-класс: 85 SKU → ~80% выручки.

---

## 5. DQ GATE — ЧЕКИ И ПОРОГИ

CF: cf-dq-00006-lac *(⚠️ ревизия после T-1-фикса от 2026-06-24 не зафиксирована в дельте — уточнить)*

| Чек | Порог | Что проверяет |
|---|---|---|
| not_empty | staging_count > 0 | Staging не пустой |
| drift_check | weekday: ≥0.10, weekend: ≥0.03 | **T-1 rev / MA7(T-8…T-2)** — НЕ T-0 (фикс 2026-06-24, см. правило 25) |
| fk_integrity | orphan_product_ids = 0 | Все product_id из staging есть в dim_products |
| freshness | lag_days ≤ 3 | MAX(DATE(transaction_date_raw)) не старше 3 дней |
| margin_sanity | bad_margin_rows = 0 | Строки с маржой > 100% выручки |
| currency_normalization | avg_revenue_kgs < 10M | Данные в KGS, не тыйынах |

---

## 6. UUID СПРАВОЧНИК

### Кастомные поля МойСклада

| Поле | Сущность | UUID |
|---|---|---|
| Срок годности | Товар | c8ae21e9-64a1-11ef-0a80-0bba00013abb |
| Страна | Контрагент | 6d6cca1e-ed85-11f0-0a80-0b1a00a4547c |

### Статусы заказов поставщику

| UUID | Статус |
|---|---|
| 491d6da5-8b37-11ef-0a80-0762000253a8 | В пути |
| 491d62b6-8b37-11ef-0a80-0762000253a7 | Прибыл |
| 87b7a192-349f-11f1-0a80-1a0f000384c2 | Прибыл частично |
| 87b7a5e5-349f-11f1-0a80-1a0f000384c3 | Отменен |

**⚠️ IN_TRANSIT_STATUS_ID = `491d6da5`** (В пути). Не путать с `491d62b6` (Прибыл).

### Каналы продаж МойСклада

| UUID | Канал |
|---|---|
| 0651f30b-4f5e-11ef-0a80-162a001acc2a | UMAI Ozon |
| 4a07eb32-2e47-11ef-0a80-0f4200606f40 | Оптовая торговля |
| 7b1781c8-87d7-11ef-0a80-02960047ce13 | Джунхай |
| a015989a-03ff-11f0-0a80-13c10010e716 | Bloom WB |
| a53854e9-2ff2-11ef-0a80-14140018b87a | UMAI WB |
| dd774cfb-1f75-11f1-0a80-19f10017e258 | К Глобал РФ Маркетплейсы |
| ddd4ee44-831b-11f0-0a80-0903001c5879 | ОФИС |
| f7e70716-4df6-11f1-0a80-0ee40053411d | К Глобал |

### Проекты МойСклада

| UUID | Проект |
|---|---|
| 448dfc24-44fc-11ef-0a80-019e0028ceab | Оптовая торговля |
| 76add853-5252-11ef-0a80-0748004359fe | Розница КР |
| b4b12ba7-2e47-11ef-0a80-0f420060821f | Маркетплейсы |
| df1c6731-2e47-11ef-0a80-16e40062e908 | Жетиген Трейдинг |

### Статусы счетов покупателям (invoiceout) *(новое, 2026-06-05)*

| UUID | Статус | Тип |
|---|---|---|
| 58dd1837-8b7f-11ef-0a80-024f0004c11e | Новый | Regular |
| 49279b1d-03b5-11f0-0a80-0b3d000268cb | Ожидает оплату | Regular |
| 58dd1fa9-8b7f-11ef-0a80-024f0004c11f | Оплачено | Regular |
| bd263b12-9c30-11ef-0a80-0e4d000e9ad0 | Частично оплачен | Regular |
| bdbcc32d-a039-11ef-0a80-037a00bf3137 | Истечение срока оплаты | Unsuccessful |
| 91d78b4f-8b2d-11ef-0a80-08b40001b6e2 | Платеж просрочен | Regular |
| 91d78bd1-8b2d-11ef-0a80-08b40001b6e3 | Под реализацию | Regular |
| bdc330f2-a039-11ef-0a80-037a00bf313b | Частичный возврат | Unsuccessful |
| bdc51a2a-a039-11ef-0a80-037a00bf3141 | Возврат | Unsuccessful |
| 81b93e00-d410-11ef-0a80-0c92000f3848 | Маркетплейс | Regular |

### Статьи расходов МойСклада (expenseitem) *(новое, 2026-06-05)*

| UUID | Статья | Примечание |
|---|---|---|
| 202adccb-fa31-11ee-0a80-0892007106c5 | Зарплата | — |
| 202b391b-fa31-11ee-0a80-0892007106c6 | Маркетинг и реклама | — |
| d3fc695e-30ca-11ef-0a80-0151002574fc | Логистика | — |
| d3fc97e4-30ca-11ef-0a80-0151002574fd | Банк (комиссия) | — |
| 8dbf9a86-0a01-11e4-a190-002590a32f46 | Налоги и сборы | — |
| 13383bd4-ec83-11ef-0a80-07df0068bb36 | Вывод прибыли | Финансовая операция, не P&L |
| 747218f2-ec89-11ef-0a80-0b6a006a92ef | Выплата тела кредита | Финансовая операция, не P&L |
| 61a39b6b-0bc9-11f0-0a80-16420018b8af | Возврат займа собственнику | Финансовая операция, не P&L |
| 8fc5c6be-f4cc-11ef-0a80-0d68000f49b4 | Неразнесенное списание | ⚠️ Требует разноски заказчиком |
| **24c0e914-2d8c-11f1-0a80-11b0000c7043** | **Перемещение исходящий** | **ИСКЛЮЧЕНО из ETL** |
| **4e1c05f2-0673-11e6-a655-0cc47a342ca4** | **Перемещение** | **ИСКЛЮЧЕНО из ETL** |
| **8dbf9374-0a01-11e4-b9bf-002590a32f46** | **Закупка товаров** | **ИСКЛЮЧЕНО из ETL** |
| **8dbf99a0-0a01-11e4-a743-002590a32f46** | **Возврат** | **ИСКЛЮЧЕНО из ETL** |

### ⚠️ Статьи расходов, обнаруженные на `entity/loss` (списание), не на платежах *(новое, 2026-06-25, см. TD-PNL-RECON-01)*

UUID статей ниже **не зафиксированы** в этой сессии (видели только `expenseItem.name` через `expand`, не резолвили bare UUID) — заполнить при следующей сессии, если потребуется фильтрация по ID, а не по имени.

| Статья | Где встречена | Примечание |
|---|---|---|
| Списания | `entity/loss`, 2 документа за май | Сумма документов (411 838,94) НЕ совпадает с П&Л (45 788,94) — не 1:1 |
| Маркетинг и реклама | `entity/loss`, 5 документов за май | Та же статья ТАКЖЕ существует на `paymentout` (UUID `202b391b...` выше) — статья делится между двумя типами документов |
| Прочие расходы | `entity/loss`, 1 документ за май | Та же статья ТАКЖЕ существует на `paymentout` |
| Комиссия | Не найдена ни на платежах, ни в проверенном срезе `entity/loss` за май | Открытый вопрос |
| Обучение | Не найдена ни на платежах, ни в проверенном срезе `entity/loss` за май | Открытый вопрос |

**Метод проверки** (`entity/loss`, май 2026, `expand=expenseItem`):
```python
import requests, os
t = os.environ.get("TOKEN")
h = {"Authorization": f"Bearer {t}"}
resp = requests.get(
    "https://api.moysklad.ru/api/remap/1.2/entity/loss",
    headers=h,
    params={"filter": "moment>=2026-05-01 00:00:00;moment<=2026-05-31 23:59:59",
            "limit": 100, "expand": "expenseItem"})
```

---

## 7. КРИТИЧЕСКИЕ ПРАВИЛА (НЕЛЬЗЯ НАРУШАТЬ)

### Данные

1. **transaction_date_raw в staging — STRING, не DATE.** Всегда: `DATE(transaction_date_raw)`
2. **transaction_date в core.fact_sales_profit — DATE.** Без CAST.
3. **revenue_kgs = 0** — пробники, не ошибка. При анализе: `AND revenue_kgs > 0`
4. **sell_quantity часто NULL** при revenue > 0 — API-поведение
5. **is_in_transit в fact_purchases ненадёжен** — фильтровать только по `status_name`
6. **Все денежные поля МойСклад API в минорных единицах валюты ДОКУМЕНТА (× 0.01), НЕ всегда в тыйынах KGS.** ⚠️ (2026-06-24, КРИТИЧНО) Аккаунт мультивалютный: KGS (база), USD (rate≈90), RUB (rate≈1.245), KZT (rate≈0.19) — см. `entity/currency`. После ÷100 результат в ВАЛЮТЕ ДОКУМЕНТА (`demand.rate.currency`), не в KGS! Обязательно умножать на курс документа (`rate.value`, если задан, иначе текущий курс валюты) ПЕРЕД суммированием в KGS. Деление на 100 без этого умножения дало 90-кратную недооценку для USD-документов — подтверждённая причина TD-RECON-01. Проверить, есть ли тот же баг в `cf-facts`/`cf-finance`. Касается также `sum`, `payedSum` в invoiceout и `sum` в paymentout/cashout — те же мультивалютные риски.
7. **dim_counterparties: JOIN всегда с** `AND scd2_is_current = TRUE`

### Код и патчи

8. **Длинный SQL только через Python open().write()** — никогда heredoc в bash
9. **Перед любым SQL-запросом** к незнакомому марту — сначала `INFORMATION_SCHEMA.COLUMNS`
10. **`rows` — зарезервированное слово BigQuery.** Использовать `total_rows`, `row_count`, `cnt`
11. **После `CREATE OR REPLACE TABLE` на марте** — обновить schema в LS (Resource → Reconnect)
12. **CF не пишут в marts** — только SQ. Патч марта = изменение SQ через `bq update --transfer_config`
13. **`bq update --transfer_config` требует** `--location=asia-east1`

### Looker Studio

14. **LS Boolean фильтры:** Exclude → поле → Equal to → true (не Include → false)
15. **Custom Query с date-фильтром** — использовать `@DS_START_DATE`/`@DS_END_DATE` вместо хардкода.
    Формат: STRING `YYYYMMDD`. Обязательно оборачивать: `PARSE_DATE('%Y%m%d', @DS_START_DATE)`.
    В редакторе источника включить **«Включить параметры диапазона дат»**.
16. **`msklad_customer_invoices_ar`** — snapshot, date range параметры НЕ включать.
17. **`msklad_expenses`** — временной ряд, date range на `moment` включать.

### Операционные

18. **FX forward-fill** — теперь cf-fx делает это автоматически при 401 от Bakai. Ручной forward-fill нужен только если cf-fx сам упал.
19. **Manual promote без DQ** допустим только если staging > 1000 строк и > 50M KGS за 90 дней
20. **После manual promote** — запустить `mode=returns, window_days=90`
21. **Standalone скрипты (load_invoices.py, load_payments.py)** — перед запуском обязательно `export TOKEN=...`. Без export Python не видит переменную.

### МойСклад API (curl)

22. **GET-запросы**: только `Authorization: Bearer $TOKEN`, без `Content-Type`. Использовать Python requests, не curl для диагностики.
23. **`--compressed`** обязателен для curl запросов к МойСклад API
24. **`invoiceout` и `paymentout`**: `expand=agent,state` и `expand=agent,expenseItem` соответственно — статус и агент приходят expanded без отдельного резолва

### Новые правила (2026-06-24)

25. **DQ drift_check — стандарт T-1.** Сравнивать выручку **вчера (T-1)** с MA7 за период T-8…T-2 из CORE_FACT. Использовать T-0 (текущий день) запрещено — неполный день даёт ложные срабатывания (False Positives).
26. **Ghost Records — фильтрация статей расходов ТОЛЬКО через `DELETE` в BQ после `MERGE`.** Никогда не фильтровать системные статьи (`EXCLUDE_EXPENSE_IDS`) на уровне Python `if/continue` во время выгрузки — это ломает обновление документов, которые клиент позже переразносит на статью-исключение (Ghost Record зависает навечно). *(Исправлено 2026-06-18 в `cf-finance`.)*
27. **Жёсткая типизация STG-загрузки.** Схема `LoadJobConfig` должна быть прописана в коде явно (избегаем `INT64 cannot be assigned to STRING`). Поле `moment` из МойСклада приходит как `TIMESTAMP` — обрезать до `DATE` на уровне Python: `row.get("moment")[:10]`. *(`cf-finance`, 2026-06-18.)*
28. **`bq` CLI недоступен в Cloud Functions (gen2 / Cloud Run).** `subprocess.run(["bq", ...])` внутри CF → `FileNotFoundError`. Только нативные библиотеки `google-cloud-bigquery` / `google-cloud-bigquery-datatransfer`. (Если `bq` нужен из Python-скрипта НЕ в CF, а в Cloud Shell/локально — см. правило 8 про heredoc; при использовании `<` redirect в `subprocess.run` обязателен `shell=True`.) *(Обнаружено при деплое `cf-finance`, 2026-06-18.)*
29. **`expand` + `limit` ≤ 100.** При `expand=` (например `expand=expenseItem`) `limit` не должен превышать 100 — иначе API МойСклада молча игнорирует `expand` и возвращает `NULL` вместо вложенного объекта (исторические данные тихо затираются). *(`cf-finance`, 2026-06-18.)*
30. **`timeout=90` на тяжёлых эндпоинтах.** Эндпоинты с вложенными позициями (`entity/purchaseorder/{id}/positions` и аналоги) могут отвечать дольше 30с. В сетевой обёртке (`helpers.py` / `_api_get`) `timeout` должен быть 90, не 30. Декораторы ретраев (`tenacity`) не спасают от `ReadTimeoutError`, если базовый `timeout` мал. *(Относится к `cf-facts` mode=purchases — точная дата фикса не подтверждена.)*
31. **id + name при парсинге ЛЮБОГО документа МойСклад.** Для закупок, платежей, отгрузок и т.д. обязательно извлекать корневой `id` (→ `*_id`, для JOIN/MERGE) И корневой `name` (→ `*_name`, человекочитаемый номер для BI). *(Относится к `cf-facts` mode=purchases — точная дата фикса не подтверждена.)*
32. **CF, обрабатывающие финансовые/чувствительные данные — проверять auth на trigger.** `cf-finance` задеплоена с `--allow-unauthenticated` (см. TD-SEC-01) — нетипично для проекта; перед добавлением новых CF сверяться с этим паттерном осознанно, а не копипастой.
33. **Формат `bq query` для Cloud Shell.** Оборачивать в `bq query --use_legacy_sql=false \` + многострочную ОДИНАРНУЮ кавычку для bash; строковые литералы внутри самого SQL — в ДВОЙНЫЕ кавычки (одинарные закроют bash-строку раньше времени). Стандарт владельца, 2026-06-24.
34. **Реконсиляция с МойСкладом — источник истины ТОЛЬКО прямой запрос к API МойСклада, никогда наши же BQ-таблицы.** Сравнение `core.*`/`marts.*` между собой (или с LS-виджетом) проверяет только внутреннюю согласованность пайплайна — это НЕ проверка полноты данных. Чтобы найти, что не доезжает от МойСклада до нас, нужен независимый прямой запрос к `api.moysklad.ru` за тот же скоуп (период/статус/фильтр), и только потом diff с BQ. Поймано владельцем 2026-06-24 на TD-RECON-01.
35. **`ROWS` — зарезервированное слово в BigQuery Standard SQL**, используется в оконных функциях (`ROWS BETWEEN ... AND ...`). Нельзя использовать как алиас колонки (`AS rows` → синтаксическая ошибка). Использовать `row_count` или аналогичное. Поймано владельцем 2026-06-24.

### Новые правила (2026-06-25)

36. **Перед тем как считать SQ/CF сломанной — сравнить timestamp последнего обновления ИСТОЧНИКА и ПОТРЕБИТЕЛЯ.** Расхождение цифр между core и mart (или между core и CF-триггером) может быть обычным лагом расписаний: SQ работает по своему расписанию (например, раз в сутки в фиксированное время), а фикс в core может прилететь ПОСЛЕ этого времени тем же днём — тогда следующий штатный прогон сам всё поправит, без вмешательства. Проверять `bq ls --transfer_run` (история запусков, FAILED/SUCCEEDED) ПЕРЕД тем, как объявлять автоматизацию сломанной. Поймано на TD-RECON-03, 2026-06-25.
37. **Traceback в Python ВСЕГДА нормализует отображаемый отступ строки кода (обычно к 4 пробелам) независимо от РЕАЛЬНОГО отступа в файле.** Нельзя делать вывод о структуре кода (уровень вложенности, отступ) по тому, как строка показана в traceback — нужно открыть сам файл. Игнорирование этого правила привело к серии неудачных патчей `main.py` (`cf-finance`) на сессии 2026-06-25.
38. **Патч по подстроке (substring match) небезопасен и НЕ идемпотентен**, если результат замены содержит исходный паттерн как часть самого себя — например, замена `"    foo()"` (4 пробела) превращает строку в `"        foo()"` (8 пробелов), которая при повторном запуске того же патч-скрипта снова матчится тем же паттерном (последние 4 из 8 пробелов + вызов), порождая дублирование. Патчить нужно по точным номерам строк (`lines[N]`) или по полному содержимому строки (`.strip() == "..."`), не по `in`/`.count()` подстроки. Поймано на сессии 2026-06-25.
39. **Долгие (>1-2 мин) ручные HTTP-вызовы CF из интерактивного терминала Cloud Shell — заворачивать в `nohup ... > log 2>&1 & disown`.** Foreground-вызов может выглядеть "зависшим" или беззвучно обрывать видимый вывод при дисконнекте сессии терминала, хотя сам HTTP-запрос и обработка на сервере продолжаются независимо. Проверять реальный результат через слой данных (например `MAX(_loaded_at)` в BQ), а не через то, что показал терминал. Поймано на TD-RECON-04, 2026-06-25.
40. **Веб-терминал Cloud Shell ненадёжен для вставки многострочного кода** (heredoc `cat << 'EOF'` и аналогичные конструкции) — быстрая вставка большого блока текста может обрываться/перемешиваться на стороне терминала. Для доставки файлов — использовать Upload (⋮ → Upload, файл попадает в `$HOME`, далее `mv` в нужную папку) или Cloud Shell Editor (`cloudshell edit <file>`). Если нужна именно команда в терминале — одна физическая строка без вложенных переносов (`python3 -c '...'` с `\n` как escape-последовательностью внутри строки, не как реальный перевод строки во вводе). Поймано на сессии 2026-06-25.
41. **`cf-finance` делает полный re-fetch всей истории `paymentout`+`cashout` при КАЖДОМ запуске, без инкрементального окна** (в отличие от `cf-facts`, где есть `window_days`). Это надёжно при небольшом объёме данных, но линейно увеличивает время выполнения и риск таймаута по мере роста — именно так возник таймаут 2026-06-25 (см. TD-CF-FINANCE-SCOPE-01). Учитывать при любых будущих изменениях `cf-finance`.
42. **П&Л-категории расходов МойСклада не ограничены платёжными документами (`paymentout`/`cashout`).** Статья расходов может частично или полностью происходить из документов списания (`entity/loss`) или потенциально других типов документов. Реконсиляция payments-only пайплайна с П&Л-отчётом МойСклада в принципе не может сойтись 1:1, если статья распределена между несколькими типами документов — нужно явно проверять `entity/loss` (и держать в уме возможность других типов) при любой будущей сверке. См. TD-PNL-RECON-01.

---

## 8. ИЗВЕСТНЫЕ ПРОБЛЕМЫ ДАННЫХ

| ID | Описание | Статус |
|---|---|---|
| TD-DATA-01 | Dr.Ceuracle: закупочные цены введены неверно, фиктивный убыток 693K KGS. После исправления → `mode=promote, window_days=90` | ⏳ Ожидает исправления заказчиком |
| TD-DATA-02 | Ghost agent ООО К ГЛОБАЛ: manual INSERT выполнен 2026-05-20 | ✅ Закрыто |
| TD-DATA-03 | cf-dim не фетчит агентов с dual-role | 📋 P2 backlog |
| TD-DATA-04 | Верифицировать источник 681K KGS по ООО К ГЛОБАЛ | 📋 P2 backlog |
| TD-DATA-05 | max_weight = 141.0 кг в dim_products — вероятная ошибка ввода. Заказчик должен исправить в МойСкладе | ⏳ На стороне заказчика |
| **TD-DATA-06** | **`Неразнесенное списание` в `fact_payments`: 58.6M KGS (цифра до фикса Ghost Records, 2026-06-05) → 0 строк за май на свежей перезагрузке 2026-06-25. Фикс пайплайна не "не сработал" — статья физически живёт не только в платежах, но и в документах списания (`entity/loss`), которые `cf-finance` не запрашивает. См. TD-PNL-RECON-01** | **🟡 Переоткрыто как методологический вопрос (не баг пайплайна) — см. TD-PNL-RECON-01** |

---

## 9. ОТКРЫТЫЙ TD BACKLOG

| ID | Описание | Приоритет |
|---|---|---|
| **TD-CF-FX** | ✅ ЗАКРЫТО (2026-06-03) | — |
| **TD-13** | marts.sales_overview: returns JOIN по временному окну вместо точной даты | P2 |
| **TD-11** | applicable=true в fetch_demands.py | P2 |
| **TD-12** | COGS переаллокация на сетах/дуо (147 строк negative margin) | P2 |
| **TD-DATA-03** | cf-dim dual-role агенты | P2 |
| **TD-DATA-04** | Верификация 681K KGS | P2 |
| **TD-BAKAI-01** | TTL токена bakai-fx-token неизвестен. При истечении → ротация по RUNBOOK §17 | P2 |
| **TD-WEIGHT-01** | Покрытие weight в dim_products ~32.6%. Мониторить ежемесячно | P3 |
| **TD-INVOICES-01** | 🔶 ЧАСТИЧНО ЗАКРЫТО (2026-06-18): `load_payments.py` мигрирован в `cf-finance` (gen2) + Cloud Scheduler. `load_invoices.py` остаётся standalone-скриптом — миграция не подтверждена | P3 |
| **TD-PAYMENTS-01** | ✅ Баг пайплайна (Ghost Records) исправлен 2026-06-18 в `cf-finance` — фильтрация перенесена на DELETE после MERGE. Остаётся: дождаться разноски от заказчика по реально неразнесённым платежам, затем `sq_marts_expenses` принудительно | P2 |
| **TD-CF-PAYMENTS-NAME** | ✅ ЗАКРЫТО (2026-06-24): CF называется `cf-finance`, https://cf-finance-xw5u2boozq-de.a.run.app, revision cf-finance-00001-wiv, Scheduler `finance-daily-update` (03:00 Asia/Bishkek). Установлено по логу деплоя | — |
| **TD-DQ-REVISION** | 🆕 (2026-06-24) Ревизия cf-dq после внедрения T-1 стандарта (drift_check) не зафиксирована в дельте — лог деплоя cf-finance этот вопрос не покрывает (другая функция). Уточнить актуальный revision ID | P3 |
| **TD-PAYMENTS-RECOUNT** | ✅ Пересчитано (2026-06-25) на свежей полной перезагрузке `fact_payments` после фикса таймаута: 4732 строки (было 4548 в v3.0). «Неразнесенное списание» = 0 строк за май — НЕ потому что разнесли, а потому что статья частично/полностью живёт на `entity/loss`, см. TD-PNL-RECON-01 | — |
| **TD-SEC-01** | ✅ Подтверждено владельцем как баг (2026-06-24): `cf-finance` задеплоена с `--allow-unauthenticated`, в отличие от остальных CF проекта. Нужен передеплой с `--no-allow-unauthenticated` + OIDC-токен для Scheduler | **P1** |
| **TD-RECON-01** | ✅ ЗАКРЫТО (2026-06-24). Фикс выкачен (`cf-facts-00007-xir`), `mode=promote` прошёл DQ Gate без блокировки. Май после фикса: 93 540 320,53 vs эталон 93 251 530,80 — 99,7% совпадение | — |
| **TD-FX-CONVERSION-01** | ✅ ЗАКРЫТО (2026-06-25). Код-фикс задеплоен в `fetch_demands.py`/`fetch_returns.py`/`fetch_purchases.py` (умножение на `currency_rate`). Подтверждено на продажах (99,7%) и на закупках (построчно 13/13, diff=0,00 — см. TD-RECON-03). Платежи (`cf-finance`) код-ревью сделан: системного `÷100 без ×rate` паттерна НЕ найдено — разрыв в платежах объясняется другой причиной (см. TD-RECON-04/TD-PNL-RECON-01), не валютой | — |
| **TD-RECON-02** | ✅ ЗАКРЫТО (2026-06-24). Починилось автоматически вслед за TD-RECON-01 — тот же mart/код. Владелец сверил разбивку по сотрудникам с интерфейсом МойСклада вручную — совпадает | — |
| **TD-RECON-03** | ✅ ЗАКРЫТО (2026-06-25). Гипотеза `window_days=90` опровергнута — `core.fact_purchases` была корректна всё время (построчная сверка 13/13 заказов «В пути» с МойСкладом, diff=0,00 KGS; сам отчёт МойСклада без даты-фильтра показал только заказы младше месяца, что само по себе опровергает гипотезу про старые отсечённые заказы). Реальная причина расхождения на дашборде — `marts.in_transit` не успел пересобраться после фикса (SQ ежедневно в 13:09 UTC, фикс в core прилетел в 22:01 UTC того же дня — обычный временной зазор, не сбой). Ручной форс-ребилд (`CREATE OR REPLACE`, идентичный канону) → 104 877 706,09 vs МойСклад 104 877 706,26 (diff 0,17 KGS). `sq_marts_in_transit` здоров, 0 FAILED за 10 дней — автоматику не трогали. Владелец подтвердил визуально на дашборде. *Мелкая нестыковка не по теме этой задачи, не блокирует закрытие: заказ `260602-2` в МойСкладе показывает «В ожидании»=0 при «Принято»=0 (у всех остальных 12 заказов «В ожидании»=«Сумма») — вероятно, отдельный документ поступления уже закрыл количество без обновления статуса заказа; не проверено дальше* | — |
| **TD-RECON-04** | ✅ ЗАКРЫТО — инфраструктурная часть (2026-06-25). Корень: `cf-finance` деплоена с `--timeout=300s`, но тянет ВСЮ историю платежей без инкрементального окна при каждом запуске (~12-13 мин) — с ростом объёма стала упираться в таймаут на каждом ночном прогоне с 2026-06-19 (504, `Scheduler retryConfig.maxRetryDuration=0s` тихо это скрывал). Фикс 1: `--timeout=1800s`. Фикс 2: после устранения таймаута всплыл отдельный баг — `trigger_marts()` (force-trigger `sq_marts_expenses`) падал `PermissionDenied` уже ПОСЛЕ успешного `MERGE`, превращая успешную загрузку в HTTP 500; обёрнут в `try/except`. Оба фикса подтверждены живым прогоном (HTTP 200, без дублей, без гонки). Содержательный вопрос (4 статьи П&Л не сходятся) вынесен в TD-PNL-RECON-01, не блокирует закрытие этой задачи | — |
| **TD-PNL-RECON-01** | 🆕 (2026-06-25) 4 статьи П&Л за май (`Списания` 45 788,94; `Комиссия` 1 775 754,88; `Неразнесенное списание` 1 260 262,00; `Обучение` 34 000,00 — суммарно 3 115 805,82, 85,6% от полного разрыва 3 639 460,63 KGS; точные цифры и метод расчёта — раздел 4.2) отсутствуют в `fact_payments` даже на свежей полной перезагрузке (опровергнута гипотеза заморозки данных). Минимум 3 из 4 статей реально встречаются в `entity/loss` (документы списания), которые `cf-finance` не запрашивает. НО прямое сложение `payments + loss` не сходится 1:1 с П&Л ни по одной статье (Списания +9x, Маркетинг +38%, Прочие расходы −31%) — методология агрегации П&Л МойСклада не установлена. «Комиссия» и «Обучение» не найдены вообще ни в одном проверенном источнике. Следующий шаг — открыть конкретный документ (`00029-00001`) в интерфейсе МойСклада и посмотреть разноску глазами | P2 |
| **TD-CF-FINANCE-SCOPE-01** | 🆕 (2026-06-25) `cf-finance` делает полный re-fetch `paymentout`+`cashout` без date-фильтра при КАЖДОМ запуске (подтверждено по коду). `--timeout=1800s` — временный обход, не масштабируется. Нужна инкрементальная загрузка по аналогии с `window_days` в `cf-facts` | P2 |
| **TD-CF-FINANCE-PERMS-01** | 🆕 (2026-06-25, не блокирует) `etl-sa` не имеет прав на BigQuery Data Transfer API для `sq_marts_expenses` (`6a22a243-...`) — `trigger_marts()` падает `PermissionDenied`, сейчас поглощается `try/except`. Решить: выдать права (точная нужная роль — см. ссылку в самой ошибке, не угадывать) ИЛИ убрать вызов целиком (рекомендация — убрать, mart обновляется по своему расписанию, тот же урок что TD-RECON-03) | P3 |
| **TD-AUTH-01** | 🟡 (2026-06-24, понижен после опровержения как причины TD-RECON-01) `msklad-token` принадлежит сотруднику стороннего приложения "Финтабло" (`uid: fintablo@koreagloballlc`), не выделенному ETL service account. Сама находка валидна (структурный риск — чужой токен), но **НЕ объясняет майский разрыв по выручке** — UI-проверка показала, что в отделе/проекте "Маркетплейсы" денег за май почти нет (1,65M из 177M). Чинить как hygiene-задачу, не как блокер TD-RECON-01 | P2 |

---

## 10. БИЗНЕС-МЕТРИКИ (актуальные цифры, 2026-06-05)

| Метрика | Значение | Примечание |
|---|---|---|
| Выручка 90д | ~162M KGS | После бэкфилла с новыми полями |
| Gross margin fully-costed | ~25% | Только транзакции с known COGS |
| GMROI аннуализированный | ~6x | Верхняя граница нормы |
| Toxic stock | 21.1% | После патча детектора |
| ABC A-класс | 85 SKU → ~80% | Лучше Парето |
| Каналы продаж | 8 штук | Включая маркетплейсы, опт, офис |
| Проекты | 4 штуки | Опт KR, Розница KR, Маркетплейсы, Жетиген |
| USD/KGS НБКР | 87.45 | На 2026-06-03 (Bakai Bank API) |
| SKU с весом | 1463/4492 (32.6%) | Растёт по мере заполнения |
| Дебиторка (unpaid) | ~122M KGS | Из них ~71M — статус «Маркетплейс» |
| Расходы в BQ | 4732 платежа *(обновлено 2026-06-25, было 4548)* | Без перемещений и черновиков; 4 статьи П&Л (~3,6M KGS) отсутствуют структурно, см. TD-PNL-RECON-01 |

---

## 11. СТРАНИЦЫ LOOKER STUDIO

| Страница | Источники LS | Назначение |
|---|---|---|
| Инвестор | msklad_sales_overview | Выручка, маржа, динамика для инвестора |
| Склад | msklad_weight_flow, msklad_inventory_health, msklad_in_transit | KPI кладовщиков, остатки, В пути |
| Операционка | msklad_sales_overview, msklad_counterparty_returns, msklad_customer_invoices_ar | Менеджеры, контрагенты, страны, дебиторка |
| Закупки в пути | msklad_in_transit | Детализация заказов поставщику |
| **Расходы** | **msklad_expenses** | **Burn rate, PnL-расходы для владельцев/инвесторов** |

---

*Версия 6.0 | 2026-06-25 | Следующее обновление: после значимых архитектурных изменений или новых инцидентов*
