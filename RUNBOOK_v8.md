# RUNBOOK: BI-пайплайн МойСклад → BigQuery → Looker Studio

**Версия:** 8.0  
**Обновлён:** 2026-06-25 — закрыты TD-RECON-03 (закупки «В пути», причина — лаг марта, не баг) и TD-RECON-04 (платежи, причина — таймаут `cf-finance` без инкрементальной загрузки + неперехваченный сбой необязательного шага). Добавлены §29-33 (mart staleness, CF-таймаут без ретраев, CF падает на необязательном шаге после успешной загрузки, патч кода через терминал, верификация долгих ручных вызовов CF) и §25.7-25.8 (реконсиляция по правильному полю, многосущностные П&Л-категории). См. PROJECT_REFERENCE_v6.md для полной хронологии  
**Предыдущая версия:** 7.0 (2026-06-24)

---

## Как пользоваться этим документом

1. Получил алерт → находишь раздел с подходящим симптомом в [быстром индексе](#быстрый-индекс).
2. Открываешь раздел → следуешь шагам сверху вниз.
3. Если шаг не помог — переходишь к следующему. Не пропускай шаги "потому что и так понятно".
4. Если дошёл до конца раздела и ничего не сработало → раздел [Эскалация](#эскалация).
5. После устранения инцидента → запиши в [Журнал инцидентов](#журнал-инцидентов).

**Правило одной руки:** не делать одновременно несколько действий. Один шаг → проверка → следующий шаг.

---

## Архитектура пайплайна

```
МойСклад REST API v1.2
        │
        │  (Cloud Functions gen2, region: asia-east1)
        ▼
┌───────────────────────────────────────────────────┐
│  cf-facts (hourly + weekly)                       │  mode=hourly → 7d rolling
│  cf-dim   (daily 03:00 KGT)                       │  mode=weekly → 90d MERGE
│  cf-fx    (daily) ← Bakai Bank OpenBanking API    │  MERGE по дате (идемпотентно)
│  cf-inventory (daily 03:00 KGT snapshot)          │
│  cf-dq    (DQ Gate, вызывается из workflow)       │
│  cf-alert (webhook для Telegram алертов)          │
│  cf-finance (daily 03:00 KGT) ⚠️ allow-unauthenticated │  MERGE paymentout+cashout → fact_payments
└───────────────────────────────────────────────────┘
        │ raw JSON (immutable)         │ BQ loads
        ▼                              ▼
  GCS: msklad-raw-msklad-bi-prod/  BigQuery: msklad-bi-prod
  (lifecycle 365 дней)             ├── stg_msklad (TTL 14d)
                                   ├── core
                                   │   ├── fact_sales_profit   (+ sales_channel, project)
                                   │   ├── fact_returns
                                   │   ├── fact_inventory
                                   │   ├── fact_purchases     (+ order_name)
                                   │   ├── fact_payments      (cf-finance, полная выгрузка + DELETE-постфильтр после MERGE)
                                   │   ├── dim_products        (+ weight)
                                   │   ├── dim_counterparties  (+ country, SCD2)
                                   │   ├── dim_employees
                                   │   ├── dim_fx_rates        (Bakai Bank → НБКР rate)
                                   │   └── dim_metadata_mappings
                                   ├── audit
                                   ├── marts
                                   │   ├── sales_overview      (+ sales_channel, project)
                                   │   ├── inventory_health
                                   │   ├── gmroi / gmroi_by_folder
                                   │   ├── abc_xyz
                                   │   ├── in_transit          (+ order_name)
                                   │   ├── supplier_price_history
                                   │   └── weight_flow         (новый, KPI кладовщиков)
                                   └── _backup
                                            ▼
                                     Looker Studio
                                     ├── Инвестор KGS
                                     ├── Склад (+ weight KPI)
                                     ├── Операционка (+ каналы, проекты)
                                     └── Закупки в пути
```

**CF URLs (актуальные):**

| CF | URL | Обновлён |
|---|---|---|
| cf-dim | https://cf-dim-xw5u2boozq-de.a.run.app | 2026-06-03 |
| cf-facts | https://cf-facts-xw5u2boozq-de.a.run.app | 2026-06-03 |
| cf-fx | https://cf-fx-xw5u2boozq-de.a.run.app | 2026-06-03 |
| cf-inventory | https://cf-inventory-xw5u2boozq-de.a.run.app | 00003-vuf |
| cf-dq | https://cf-dq-xw5u2boozq-de.a.run.app | 00006-lac |
| cf-finance | https://cf-finance-xw5u2boozq-de.a.run.app | cf-finance-00006-piv (2026-06-25) |

**Расписание запусков:**

| Компонент | Расписание | Оркестрация |
|---|---|---|
| msklad-pipeline-hourly | каждый час | Cloud Scheduler → Cloud Workflows |
| msklad-pipeline-weekly | воскресенье 01:00 UTC | Cloud Scheduler → Cloud Workflows |
| CF-Dim | ежедневно 03:00 KGT | Cloud Scheduler → CF напрямую |
| cf-finance | ежедневно 03:00 KGT (`finance-daily-update`, cron `0 3 * * *`). ⚠️ `retryConfig.maxRetryDuration=0s` — ретраев нет, сбой тихий (см. §30) | Cloud Scheduler → CF напрямую, HTTP POST |
| Marts SQ | ежедневно (для большинства); точное время у каждого СВОЁ, не "каждые 2ч" в общем случае — см. PROJECT_REFERENCE §3 за точными Config ID/расписанием. `sq_marts_in_transit` — конкретно 13:09 UTC (уточнено 2026-06-25, см. §29) | BigQuery Scheduled Queries |

**Порядок шагов в msklad-pipeline-hourly:**
`step_dim → step_fx → step_facts (mode=hourly) → step_dq → step_promote (window=7) → step_purchases (window=90, non-blocking)`

**Scheduled Queries Config IDs:**

| SQ Name | Config ID |
|---|---|
| sq_audit_dim_products_snapshot | 69fc93d1-0000-2d64-bdd1-30fd381336b4 |
| sq_audit_dim_counterparties_snapshot | 69fc9c75-0000-2ab4-91b3-883d24f4db64 |
| sq_audit_dim_employees_snapshot | 69fc9d6e-0000-2ab4-91b3-883d24f4db64 |
| sq_marts_inventory_health | 69fd92d9-0000-2372-ad37-582429aca3ec |
| sq_marts_sales_overview | 69ff34b4-0000-2b2b-a390-14c14ef7af10 |
| sq_marts_gmroi_by_folder | 6a004e88-0000-2e7d-bf20-9898fbb40f95 |
| sq_marts_gmroi | 6a006664-0000-2739-86f5-7474463a7ac5 |
| sq_marts_abc_xyz | 6a020b2c-0000-2dd6-96d2-883d24f52bd4 |
| sq_marts_in_transit | 6a0aa537-0000-260f-b391-d43a2cee6b87 |
| sq_marts_supplier_price_history | 6a0b0f25-0000-2893-be44-d43a2cc31f97 |
| **sq_marts_weight_flow** | **6a1f9418-0000-276f-a1e4-d4f547ee7418** |
| sq_marts_customer_invoices_ar | 6a23f3ea-0000-2952-853d-582429be7ecc |
| **sq_marts_expenses** | **6a22a243-0000-20fd-a458-883d24f4cad4** *(⚠️ цель упавшего `trigger_marts()` в `cf-finance`, см. §31)* |

*(Таблица была неполной с версии 5.0 PROJECT_REFERENCE, 2026-06-05 — две последние строки добавлены 2026-06-25 для согласованности между документами.)*

Путь для всех: `projects/420804682491/locations/asia-east1/transferConfigs/{Config ID}`

---

## Быстрый индекс

| Симптом / алерт | Раздел |
|---|---|
| Алерт "CF упала" / 5xx ошибка | [1. Cloud Function упала](#1-cloud-function-упала) |
| Алерт "DQ Gate провалился" | [2. DQ Gate провалился](#2-dq-gate-провалился) |
| Алерт "выручка вчера < 10% от 7-day MA" | [3. Drift по выручке](#3-drift-по-выручке) |
| Алерт "MAX(transaction_date) старше 6 часов" | [4. Данные не свежие](#4-данные-не-свежие) |
| Дашборд показывает 0 / пусто | [5. Дашборд пустой](#5-дашборд-пустой) |
| МойСклад API возвращает 429 / 5xx | [6. Проблемы с API МойСклад](#6-проблемы-с-api-мойсклад) |
| Алерт "Workflow FAILED/CANCELLED" | [7. Workflows упал](#7-workflows-упал) |
| Цифры "поехали" задним числом | [8. Дрейф исторических данных](#8-дрейф-исторических-данных) |
| UUID кастомного поля изменился | [9. UUID кастомного поля изменился](#9-uuid-кастомного-поля-изменился) |
| Менеджер уволился / переназначен | [10. Изменение менеджера контрагентов](#10-изменение-менеджера-контрагентов) |
| Нужно полностью пересобрать core из GCS | [11. Полная пересборка core из raw](#11-полная-пересборка-core-из-raw) |
| Нужно откатить core к состоянию N часов назад | [12. Откат через BigQuery time travel](#12-откат-через-bigquery-time-travel) |
| Алерт "Workflow silent skip" / нет executions 2ч | [7. Workflows упал → шаг 7.5](#7-workflows-упал) |
| FX lag > 3 дня / cf-fx вернул degraded | [13. FX-курсы: диагностика и forward-fill](#13-fx-курсы-диагностика-и-forward-fill) |
| cf-fx: `bakai_token_expired` в логах | [17. Ротация токена Bakai Bank](#17-ротация-токена-bakai-bank) |
| DQ падает каждое воскресенье / в праздник | [14. DQ drift false positive (выходные)](#14-dq-drift-false-positive-выходные) |
| График LS сломался после rebuild марта | [15. LS stale schema после mart rebuild](#15-ls-stale-schema-после-mart-rebuild) |
| DQ падает из-за freshness (пустой день) | [16. DQ freshness false positive (пустой день)](#16-dq-freshness-false-positive-пустой-день) |
| Вес на графиках не растёт / 0 | [18. Weight flow: низкое покрытие](#18-weight-flow-низкое-покрытие) |
| CF упала: `FileNotFoundError: bq` | [19. bq CLI недоступен в CF](#19-cf-упала-с-filenotfounderror-bq) |
| Расходы массово "Не указана" | [20. expand + limit → "Не указана"](#20-расходы-массово-получают-статус-не-указана-expand-и-limit) |
| "Неразнесённое списание" висит, хотя клиент разнёс | [21. Ghost Records](#21-ghost-records-неразнесённое-списание-висит-хотя-клиент-всё-разнёс) |
| На дашборде UUID вместо номера документа/заказа | [22. UUID вместо номера документа](#22-uuid-вместо-номера-документа-на-дашборде) |
| `subprocess` + `bq query` падает с USAGE | [23. subprocess + bq + redirect](#23-subprocess-bq-query-и-redirect-ошибка-usage) |
| `ReadTimeoutError` на cf-facts mode=purchases | [24. Timeout на тяжёлых эндпоинтах](#24-readtimeouterror-на-тяжёлых-эндпоинтах-закупки) |
| Заказчик говорит "цифры не бьются с МойСкладом" | [25. Реконсиляция с МойСкладом](#25-реконсиляция-с-мойскладом-числа-не-совпадают) |
| Суммы в разы (10-90x) меньше реальных на отдельных позициях | [26. Мультивалютные документы](#26-выручкасуммы-аномально-малы-мультивалютные-документы) |
| `curl` к CF вернул `status:ok`, но данные не поменялись | [27. Деплой не прошёл, но прогон "успешен"](#27-cf-успешно-прогнала-режим-но-изменения-в-коде-не-применились) |
| `mode=weekly` отработал, а дашборд старый | [28. weekly без promote](#28-modeweekly-загрузил-данные-а-дашбордcore-не-изменился) |
| Mart показывает старые цифры, хотя core уже свежий и SQ не падает | [29. Mart-staleness: лаг между core и расписанием марта](#29-mart-показывает-старые-цифры-хотя-core-уже-обновился) |
| CF падает по таймауту каждую ночь, Scheduler "тихо" это терпит | [30. CF таймаутит без видимых алертов](#30-cf-таймаутит-каждую-ночь-без-видимых-алертов) |
| CF вернула 500, но в логе видно что MERGE прошёл успешно ДО краша | [31. CF падает 500 на необязательном шаге](#31-cf-падает-500-на-необязательном-шаге-после-успешной-загрузки) |
| Патч main.py через терминал не применяется / ломается | [32. Патч кода через терминал Cloud Shell](#32-патч-кода-через-терминал-cloud-shell-ломается) |
| Ручной `curl` к CF "висит" без вывода / непонятно, прошёл ли запрос | [33. Верификация долгого ручного вызова CF](#33-верификация-долгого-ручного-вызова-cf) |

---

## Где смотреть, что происходит

### Логи Cloud Functions (jsonPayload.message)

⚠️ CF gen2 пишут структурированные логи. Фильтровать по `jsonPayload.message`.

**В UI (Cloud Logging → Log Explorer):**
```
resource.type="cloud_run_revision"
resource.labels.service_name="cf-facts"
jsonPayload.message=~"ERROR|FAILED|exception"
```

**Через CLI:**
```bash
gcloud logging read \
  'resource.type="cloud_run_revision" AND resource.labels.service_name="cf-facts" AND severity>=ERROR' \
  --project=msklad-bi-prod \
  --limit=50 \
  --format="table(timestamp,jsonPayload.message)"
```

**❌ Не использовать:** `gcloud functions logs read cf-facts` — не работает для gen2.

### Логи Cloud Workflows
```bash
gcloud workflows executions list msklad-pipeline-hourly \
  --project=msklad-bi-prod \
  --location=asia-east1 \
  --filter="state=FAILED OR state=CANCELLED" \
  --limit=10
```

Детали упавшего execution:
```bash
gcloud workflows executions describe <EXECUTION_NAME> \
  --workflow=msklad-pipeline-hourly \
  --location=asia-east1 \
  --format="json(error.context)"
```

### Состояние BQ таблиц

```sql
SELECT
  'fact_sales_profit' AS tbl, MAX(transaction_date) AS latest, COUNT(*) AS rows
FROM `msklad-bi-prod.core.fact_sales_profit`
UNION ALL
SELECT 'fact_inventory', CAST(MAX(date_snapshot) AS DATE), COUNT(*)
FROM `msklad-bi-prod.core.fact_inventory`
UNION ALL
SELECT 'fact_returns', MAX(return_date), COUNT(*)
FROM `msklad-bi-prod.core.fact_returns`
UNION ALL
SELECT 'fact_purchases', MAX(order_date), COUNT(*)
FROM `msklad-bi-prod.core.fact_purchases`
UNION ALL
SELECT 'dim_fx_rates', MAX(date), COUNT(*)
FROM `msklad-bi-prod.core.dim_fx_rates`;
```

### ⚠️ Правило: длинные SQL только через Python (М-22)

```python
import subprocess, json
NEW_SQL = """..."""
params = json.dumps({"query": NEW_SQL})
subprocess.run(["bq", "update", "--transfer_config", "--params", params, CONFIG_PATH])
```

### ⚠️ Правило: фильтр "в пути" в fact_purchases

```sql
-- ПРАВИЛЬНО
WHERE status_name IN ('В пути', 'Прибыл частично') AND in_transit_sum_kgs > 0
-- НЕПРАВИЛЬНО: is_in_transit ненадёжен
```

### ⚠️ Правило: bq CLI недоступен в Cloud Functions (gen2)

В среде Cloud Functions (gen2 / Cloud Run) нет установленной утилиты `bq`. Вызов `subprocess.run(["bq", ...])` внутри CF падает с `FileNotFoundError`. Для SQL-запросов и Data Transfer из кода CF — только нативные библиотеки `google-cloud-bigquery` и `google-cloud-bigquery-datatransfer`. Подробнее → [§19](#19-cf-упала-с-filenotfounderror-bq).

### ⚠️ Правило: `expand` + `limit` в МойСклад API

При `expand=` (например `expand=expenseItem`) параметр `limit` **не должен превышать 100**. С `limit=1000` API не ошибается, но молча игнорирует `expand` и возвращает `NULL` вместо вложенного объекта — данные в BQ тихо затираются. Подробнее → [§20](#20-расходы-массово-получают-статус-не-указана-expand-и-limit).

### ⚠️ Правило: timeout на тяжёлых эндпоинтах МойСклад

Эндпоинты с вложенными позициями (`entity/purchaseorder/{id}/positions` и аналоги) могут отвечать дольше 30с. В сетевой обёртке (`helpers.py` / `_api_get`) параметр `timeout` должен быть **90**, не 30. Общий timeout самой CF (например 540с) трогать отдельно не нужно. Подробнее → [§24](#24-readtimeouterror-на-тяжёлых-эндпоинтах-закупки).

### ⚠️ Правило: id + name при парсинге документов МойСклад

Для ЛЮБОГО документа МойСклад (закупки, платежи, отгрузки и т.д.) обязательно извлекать **обе** пары полей: корневой `id` (→ `*_id`, для JOIN/MERGE) и корневой `name` (→ `*_name`, человекочитаемый номер для BI). Подробнее → [§22](#22-uuid-вместо-номера-документа-на-дашборде).

### ⚠️ Находка: `cf-finance` задеплоена с `--allow-unauthenticated`

В отличие от остальных CF проекта (вызов через `Authorization: Bearer $(gcloud auth print-identity-token)`), `cf-finance` (платежи, financial data) доступна по URL без аутентификации. Не подтверждено, намеренно это или нет — см. `PROJECT_REFERENCE` TD-SEC-01. Перед деплоем новых CF с финансовыми/чувствительными данными — сверяться с этим паттерном осознанно.

### Состояние GCS raw
```bash
gsutil ls -l gs://msklad-raw-msklad-bi-prod/ | sort -k2 | tail -20
```

---

## 1. Cloud Function упала

**Симптом:** Алерт "msklad-cf-error" / статус `Failed`.

**1.1.** Открой логи упавшей функции.

**1.2.** Найди последнюю строку с severity `ERROR`. Скопируй текст ошибки.

**1.3.** Сопоставь с таблицей:

| Текст в ошибке | Куда дальше |
|---|---|
| `429 Too Many Requests` | [6. API МойСклад](#6-проблемы-с-api-мойсклад) |
| `503` / `502` / `504` | [6. API МойСклад](#6-проблемы-с-api-мойсклад) |
| `Memory limit exceeded` | Шаг 1.4 |
| `Function execution took longer` | Шаг 1.5 |
| `Could not get secret` / `permission denied` | Шаг 1.6 |
| `BigQuery: ... already exists` / `MERGE conflict` | Шаг 1.7 |
| `KeyError` / `TypeError` / `JSONDecodeError` | Шаг 1.8 |
| `dim_fx_rates устарела` | [13. FX-курсы](#13-fx-курсы-диагностика-и-forward-fill) |
| `bakai_token_expired` | [17. Ротация токена Bakai](#17-ротация-токена-bakai-bank) |
| Ничего из этого | Шаг 1.9 |

**1.4. Memory limit exceeded:**
```bash
gcloud functions deploy cf-facts \
  --gen2 --runtime=python312 --region=asia-east1 \
  --service-account=etl-sa@msklad-bi-prod.iam.gserviceaccount.com \
  --memory=2048MB --timeout=540s \
  --set-secrets="MSKLAD_TOKEN=msklad-token:latest" \
  --trigger-http
```

**1.5. Timeout:** Проверь размер GCS файлов. Если > 2x обычного → увеличь timeout до 1800s.

**1.6. Secret Manager / permission denied:**
```bash
gcloud secrets add-iam-policy-binding msklad-token \
  --member="serviceAccount:etl-sa@msklad-bi-prod.iam.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor" \
  --project=msklad-bi-prod
```

Если токен МойСклад истёк (401):
```bash
python3 -c "
import subprocess
token = input('Введи новый токен: ')
with open('/tmp/new_token.txt', 'w') as f: f.write(token)
subprocess.run(['gcloud', 'secrets', 'versions', 'add', 'msklad-token',
    '--data-file=/tmp/new_token.txt', '--project=msklad-bi-prod'])
"
```

**1.7. BigQuery MERGE conflict:**
```bash
bq query --use_legacy_sql=false \
  'TRUNCATE TABLE `msklad-bi-prod.stg_msklad.fact_sales_staging`'
```

**1.8. Ошибка парсинга:** Не правь код в проде. Приостанови Scheduler:
```bash
gcloud scheduler jobs pause msklad-pipeline-hourly-trigger --location=asia-east1
```

**1.9. Неизвестная ошибка:** Вызови CF вручную. Если повторилась → эскалация.

**1.10. После починки:**
```bash
bq query --use_legacy_sql=false \
  'SELECT MAX(transaction_date), MAX(_loaded_at) FROM `msklad-bi-prod.core.fact_sales_profit`'
```

---

## 2. DQ Gate провалился

**Симптом:** Алерт "msklad-dq-gate-failed".

**2.1.** Запусти cf-dq вручную:
```bash
curl -X POST https://cf-dq-xw5u2boozq-de.a.run.app \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $(gcloud auth print-identity-token)" \
  -d '{}'
```

| Чек | Что значит | Куда дальше |
|---|---|---|
| `not_empty` | Staging пустой | Шаг 2.2 |
| `drift_check` | Выручка резко упала/выросла | [3. Drift](#3-drift-по-выручке) |
| `fk_integrity` | product_id не в dim'ах | Шаг 2.3 |
| `freshness` | Данные старше 3 дней | [16. Freshness](#16-dq-freshness-false-positive-пустой-день) |
| `margin_sanity` | Маржа > 100% выручки | Шаг 2.4 |
| `currency_normalization` | Суммы в тыйынах | Шаг 2.5 |

**2.2.** Если staging пуст — проверь МойСклад UI. Если данные есть → [6. API](#6-проблемы-с-api-мойсклад).

**2.3. FK integrity:**
```bash
bq query --use_legacy_sql=false \
'SELECT DISTINCT f.product_id
FROM `msklad-bi-prod.stg_msklad.fact_sales_staging` f
LEFT JOIN `msklad-bi-prod.core.dim_products` d ON f.product_id = d.product_id
WHERE d.product_id IS NULL LIMIT 20;'
```
Если нашлись → запусти cf-dim вручную.

**2.4. Margin sanity:**
```bash
bq query --use_legacy_sql=false \
'SELECT product_id, revenue_kgs, cogs_kgs, margin_kgs / NULLIF(revenue_kgs,0) AS margin_pct
FROM `msklad-bi-prod.stg_msklad.fact_sales_staging`
WHERE margin_kgs / NULLIF(revenue_kgs,0) > 1 LIMIT 20;'
```

**2.5. Currency normalization:** Если max(revenue_kgs) > 10M → тыйыны. Не промоуть до исправления.

**Текущие пороги DQ Gate (cf-dq-00006-lac):**
- DQ_DRIFT_THRESHOLD = 0.10 (weekday)
- DQ_DRIFT_WEEKEND_THRESHOLD = 0.03 (weekend)
- DQ_FRESHNESS_MAX_DAYS = 3
- DQ_CURRENCY_MAX_AVG_REV = 10_000_000
- **Стандарт T-1:** `drift_check` всегда сравнивает T-1 vs MA7(T-8…T-2), никогда T-0 (см. §3)

---

## 3. Drift по выручке

**Стандарт расчёта (закреплён в cf-dq, T-1):** `drift_check` НЕ использует данные текущего дня (T-0) — сравнение неполного дня с полными историческими днями даёт ложные срабатывания. Проверяется выручка за **вчера (T-1)** против скользящей средней за 7 полных дней (`ma7`, период T-8…T-2 из CORE_FACT). Если меняешь логику внутри `cf-dq` — не нарушай это правило.

**3.1.** Проверь динамику:
```bash
bq query --use_legacy_sql=false \
'SELECT transaction_date, SUM(revenue_kgs) AS daily_revenue,
  AVG(SUM(revenue_kgs)) OVER (ORDER BY transaction_date ROWS BETWEEN 7 PRECEDING AND 1 PRECEDING) AS ma7
FROM `msklad-bi-prod.core.fact_sales_profit`
WHERE transaction_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 14 DAY)
GROUP BY 1 ORDER BY 1 DESC;'
```

**3.2.** Принудительный reload если подтверждён false positive:
```bash
curl -X POST https://cf-facts-xw5u2boozq-de.a.run.app \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $(gcloud auth print-identity-token)" \
  -d '{"mode": "hourly"}'
```

---

## 4. Данные не свежие

**4.1.**
```bash
bq query --use_legacy_sql=false \
'SELECT MAX(transaction_date), TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), MAX(_loaded_at), HOUR) AS hours_since_load
FROM `msklad-bi-prod.core.fact_sales_profit`;'
```

**4.2.** Если `_loaded_at` старше 2 часов → workflow не запускался:
```bash
gcloud workflows executions list msklad-pipeline-hourly --location=asia-east1 --limit=5
gcloud scheduler jobs resume msklad-pipeline-hourly-trigger --location=asia-east1
gcloud workflows run msklad-pipeline-hourly --location=asia-east1
```

---

## 5. Дашборд пустой

**5.1.** Проверь марты:
```bash
bq query --use_legacy_sql=false \
'SELECT "sales_overview" AS tbl, COUNT(*) AS cnt FROM `msklad-bi-prod.marts.sales_overview`
UNION ALL SELECT "weight_flow", COUNT(*) FROM `msklad-bi-prod.marts.weight_flow`
UNION ALL SELECT "inventory_health", COUNT(*) FROM `msklad-bi-prod.marts.inventory_health`
UNION ALL SELECT "in_transit", COUNT(*) FROM `msklad-bi-prod.marts.in_transit`;'
```

**5.2.** Если марты пустые — принудительный rebuild:
```bash
bq mk --transfer_run \
  --run_time=$(date -u +%Y-%m-%dT%H:%M:%SZ) \
  projects/420804682491/locations/asia-east1/transferConfigs/69ff34b4-0000-2b2b-a390-14c14ef7af10
```

**5.3.** Если марты не пустые → проверь Date range фильтр в LS.

**5.4. LS Boolean фильтры (M-11):**
- ✅ Exclude → поле → Equal to → true
- ❌ Include → поле → Equal to → false

**5.5.** После rebuild марта → Reconnect schema в LS (см. §15).

---

## 6. Проблемы с API МойСклад

```bash
TOKEN=$(gcloud secrets versions access latest --secret=msklad-token --project=msklad-bi-prod)
python3 -c "
import requests
r = requests.get('https://api.moysklad.ru/api/remap/1.2/entity/organization',
    headers={'Authorization': f'Bearer $TOKEN'})
print(r.status_code)
"
```

**6.1. 429** — подожди 5 минут, перезапусти CF.

**6.2. 503/502/504** — статус: https://status.moysklad.ru

**6.3. 401** — токен МойСклад истёк. Обнови через Secret Manager (см. шаг 1.6).

**6.4. 415** — GET-запросы к МойСклад API должны делаться через Python requests, не curl с Content-Type.

---

## 7. Workflows упал

**7.1.** Найди упавший execution:
```bash
gcloud workflows executions list msklad-pipeline-hourly \
  --location=asia-east1 --limit=5 \
  --format="table(name.basename(),state,startTime)"
```

**7.2.** Получи ошибку:
```bash
gcloud workflows executions describe <EXECUTION_NAME> \
  --workflow=msklad-pipeline-hourly --location=asia-east1 \
  --format="json(error.context)"
```

**7.3.** Маппинг шагов:

| Шаг | Причина | Куда |
|---|---|---|
| raise_dim | CF-Dim упал | Логи cf-dim |
| raise_fx | CF-FX упал | [13. FX](#13-fx-курсы-диагностика-и-forward-fill) или [17. Bakai token](#17-ротация-токена-bakai-bank) |
| raise_facts | CF-Facts hourly | Логи cf-facts |
| raise_dq | CF-DQ crashed | Логи cf-dq |
| raise_dq_failed | DQ Gate FAILED | [2. DQ Gate](#2-dq-gate-провалился) |
| raise_promote | Promote упал | Логи cf-facts mode=promote |

**7.4.** Запусти workflow вручную:
```bash
gcloud workflows run msklad-pipeline-hourly --location=asia-east1
```

**7.5. Silent skip:**
```bash
gcloud scheduler jobs resume msklad-pipeline-hourly-trigger --location=asia-east1
```

---

## 8. Дрейф исторических данных

Нормальное поведение — FIFO пересчитывается при новых поставках.

**8.1.** Объясни заказчику: данные за последние 90 дней уточняются еженедельно.

**8.2.** Принудительный rolling reload:
```bash
curl -X POST https://cf-facts-xw5u2boozq-de.a.run.app \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $(gcloud auth print-identity-token)" \
  -d '{"mode": "promote", "window_days": 90}'
```

---

## 9. UUID кастомного поля изменился

**Актуальные UUID:**

| Поле | UUID |
|---|---|
| Срок годности (товар) | c8ae21e9-64a1-11ef-0a80-0bba00013abb |
| Страна (контрагент) | 6d6cca1e-ed85-11f0-0a80-0b1a00a4547c |
| Статус "В пути" (заказ поставщику) | 491d6da5-8b37-11ef-0a80-0762000253a8 |

**9.1.** Проверь актуальные UUID:
```bash
bq query --use_legacy_sql=false 'SELECT * FROM `msklad-bi-prod.core.dim_metadata_mappings`;'
```

**9.2.** Если изменился — обнови таблицу и перезапусти CF-Dim.

---

## 10. Изменение менеджера контрагентов

SCD2 на `dim_counterparties.owner_employee` отработает автоматически при следующем CF-Dim.

**10.1.** Запусти CF-Dim вручную или дождись ежедневного прогона.

**10.2.** Проверь что SCD2 отработал — должно быть две записи на каждого изменившегося агента.

---

## 11. Полная пересборка core из raw

**11.1.** Backup:
```bash
bq query --use_legacy_sql=false \
'CREATE TABLE `msklad-bi-prod._backup.fact_sales_profit_YYYYMMDD`
CLONE `msklad-bi-prod.core.fact_sales_profit`;'
```

**11.2.** Очистить core → **11.3.** Запустить пересборку из GCS.

---

## 12. Откат через BigQuery time travel

```bash
bq query --use_legacy_sql=false \
'CREATE OR REPLACE TABLE `msklad-bi-prod.core.fact_sales_profit_restored` AS
SELECT * FROM `msklad-bi-prod.core.fact_sales_profit`
FOR SYSTEM_TIME AS OF TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 6 HOUR);'
```

После верификации — DROP оригинала, RENAME restored.

---

## 13. FX-курсы: диагностика и forward-fill

**Контекст (обновлено 2026-06-03):** cf-fx теперь использует Bakai Bank OpenBanking API вместо НБКР XLS. Основной источник проблем — истечение JWT-токена (→ §17). Но forward-fill остаётся актуальным при любом сбое cf-fx.

### Диагностика
```bash
bq query --use_legacy_sql=false \
'SELECT MAX(date) AS last_fx_date,
  DATE_DIFF(CURRENT_DATE(), MAX(date), DAY) AS lag_days
FROM `msklad-bi-prod.core.dim_fx_rates`;'
```

### Шаги

**13.1.** Если `lag_days = 0` — всё ок.

**13.2.** Если `lag_days >= 1` — cf-fx не отработал сегодня. Проверь логи cf-fx:
```bash
gcloud logging read \
  'resource.type="cloud_run_revision" AND resource.labels.service_name="cf-fx" AND severity>=WARNING' \
  --project=msklad-bi-prod --limit=20 \
  --format="table(timestamp,jsonPayload.message)"
```

**13.3.** Если в логах `bakai_token_expired` → [17. Ротация токена Bakai](#17-ротация-токена-bakai-bank).

**13.4.** Если cf-fx падал по другой причине → forward-fill вручную:
```bash
bq query --use_legacy_sql=false \
'INSERT INTO `msklad-bi-prod.core.dim_fx_rates` (date, rate_kgs_per_usd)
SELECT d AS date,
  (SELECT rate_kgs_per_usd FROM `msklad-bi-prod.core.dim_fx_rates`
   ORDER BY date DESC LIMIT 1) AS rate_kgs_per_usd
FROM UNNEST(GENERATE_DATE_ARRAY(
  DATE_ADD((SELECT MAX(date) FROM `msklad-bi-prod.core.dim_fx_rates`), INTERVAL 1 DAY),
  CURRENT_DATE()
)) AS d
WHERE d NOT IN (SELECT date FROM `msklad-bi-prod.core.dim_fx_rates`);'
```

**13.5.** Верифицировать:
```bash
bq query --use_legacy_sql=false \
'SELECT date, rate_kgs_per_usd FROM `msklad-bi-prod.core.dim_fx_rates`
ORDER BY date DESC LIMIT 7;'
```

**13.6.** После forward-fill → запусти CF-Dim (он проверяет FX lag при старте):
```bash
curl -X POST https://cf-dim-xw5u2boozq-de.a.run.app \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $(gcloud auth print-identity-token)" \
  -d '{}'
```

---

## 14. DQ drift false positive (выходные)

**Контекст:** Пороги снижены weekday 0.10, weekend 0.03 (cf-dq-00006-lac). Если всё равно падает в выходные → см. §16.

### Диагностика
```bash
bq query --use_legacy_sql=false \
'SELECT
  DATE(transaction_date_raw) AS tx_date,
  COUNT(*) AS tx_count,
  ROUND(SUM(revenue_kgs)) AS revenue_kgs
FROM `msklad-bi-prod.stg_msklad.fact_sales_staging`
WHERE DATE(transaction_date_raw) >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)
GROUP BY tx_date ORDER BY tx_date DESC;'
```

**Обходное решение (только при подтверждённом false positive):**
```bash
# Убедиться что staging > 1000 строк и > 50M KGS
bq query --use_legacy_sql=false \
'SELECT COUNT(*) AS rows, ROUND(SUM(revenue_kgs),0) AS revenue
FROM `msklad-bi-prod.stg_msklad.fact_sales_staging`;'

# Manual promote
curl -X POST https://cf-facts-xw5u2boozq-de.a.run.app \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $(gcloud auth print-identity-token)" \
  -d '{"mode": "promote", "window_days": 90}'
```

---

## 15. LS stale schema после mart rebuild

**Решение:**
```
Resource → Manage added data sources → Найти источник → Edit → Edit Connection → Reconnect → Apply → Done
```

**Правило:** После любого принудительного rebuild марта — Reconnect в LS. 1 минута.

---

## 16. DQ freshness false positive (пустой день)

**Симптом:** `failed_checks: ["freshness"]`, `lag_days=2` или `3`.

**Алгоритм:**

| lag_days | Ситуация | Действие |
|---|---|---|
| 2–3 | Пустые дни (праздник, выходные) | Manual promote, ждать свежих данных |
| > 5 | Возможная реальная проблема | Проверить МойСклад → если данные есть → [6. API](#6-проблемы-с-api-мойсклад) |
| 7+ | Критический gap | Эскалация |

```bash
curl -X POST https://cf-facts-xw5u2boozq-de.a.run.app \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $(gcloud auth print-identity-token)" \
  -d '{"mode": "promote", "window_days": 90}'
```

После promote → запустить workflow вручную. Пайплайн самовосстановится как только в МойСкладе появятся свежие транзакции.

---

## 17. Ротация токена Bakai Bank *(новый раздел, 2026-06-03)*

**Симптом:** cf-fx возвращает:
```json
{"status":"degraded","error":"bakai_token_expired — update bakai-fx-token in Secret Manager"}
```

**Контекст:** JWT-токен Bakai Bank с неизвестным TTL. При истечении cf-fx делает forward-fill автоматически, но токен нужно обновить вручную.

### Шаги

**17.1.** Запросить новые one-time credentials у Бакай Банк:
- Call-центр: +996 (312) 61-00-61
- Попросить: «нам нужны новые credentials для подключения к GetRateDirectory (OpenBanking API)»
- Получишь: Логин и Пароль (одноразовые)

**17.2.** Выполнить аутентификацию **на маке** (не в CloudShell — исторически работало с мака):
```bash
# На Mac в терминале
python3 << 'EOF'
import subprocess, requests, os

base = 'https://openbanking-api.bakai.kg'

auth = requests.post(f'{base}/Auth/Login',
    json={'login': 'ЛОГИН_СЮДА', 'password': 'ПАРОЛЬ_СЮДА'},
    headers={'Content-Type': 'application/json'})

print(f'Auth: {auth.status_code}')

if auth.status_code == 200:
    token = auth.json()['token']
    print(f'Токен получен, длина: {len(token)}')

    with open('/tmp/bakai_token_new.txt', 'w') as f:
        f.write(token)

    r = subprocess.run(['gcloud', 'secrets', 'versions', 'add', 'bakai-fx-token',
        '--data-file=/tmp/bakai_token_new.txt', '--project=msklad-bi-prod'],
        capture_output=True, text=True)
    os.remove('/tmp/bakai_token_new.txt')
    print('Secret Manager:', r.stdout.strip() or r.stderr.strip())

    # Тест
    test = requests.get(f'{base}/api/Directory/GetRateDirectory',
        headers={'Authorization': f'Bearer {token}'})
    print(f'API тест: {test.status_code}')
    if test.status_code == 200:
        for rate in test.json().get('officialRates', []):
            if rate.get('currencySymbol') == 'USD':
                print(f'USD/KGS: {rate["rate"]}')
else:
    print('Ошибка:', auth.text)
EOF
```

**17.3.** Если API тест = 401 после сохранения → банк должен активировать credentials через личный кабинет. Связаться с Бакай Банк и сообщить что вы «постучались» (сделали Auth запрос) — они активируют в своей системе.

**17.4.** Smoke-test cf-fx после ротации:
```bash
curl -X POST https://asia-east1-msklad-bi-prod.cloudfunctions.net/cf-fx \
  -H "Authorization: Bearer $(gcloud auth print-identity-token)" \
  -H "Content-Type: application/json" \
  -d '{}'
# Ожидаем: "status":"ok","source":"bakai_bank_api"
```

**17.5.** Записать в журнал инцидентов дату ротации.

### ⚠️ Критические правила

- Credentials **одноразовые** — не запускать Auth повторно с теми же логином/паролем
- Токен сохранять **только через Python файловый подход** (не `echo -n "..." | gcloud`) — длинный токен искажается в bash
- **Секрет: bakai-fx-token** (не msklad-token)
- При истечении cf-fx делает **автоматический forward-fill** — данные не теряются, но курс не обновляется

---

## 18. Weight flow: низкое покрытие *(новый раздел, 2026-06-03)*

**Симптом:** Графики вес/КPI кладовщиков показывают маленькие цифры или нули для многих SKU.

**Контекст:** marts.weight_flow показывает реальный вес только для SKU у которых заполнено поле `weight` в МойСкладе. Покрытие ~32.6% на старте (1463/4492 SKU). Это штатная ситуация — заказчик заполняет данные постепенно.

**18.1.** Проверить текущее покрытие:
```bash
bq query --use_legacy_sql=false \
'SELECT COUNTIF(weight > 0) AS with_weight,
  COUNT(*) AS total,
  ROUND(COUNTIF(weight > 0) / COUNT(*) * 100, 1) AS coverage_pct
FROM `msklad-bi-prod.core.dim_products`;'
```

**18.2.** После массового заполнения весов в МойСкладе — форсировать обновление:
```bash
# 1. Запустить CF-Dim (подтянет новые weight значения)
curl -X POST https://cf-dim-xw5u2boozq-de.a.run.app \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $(gcloud auth print-identity-token)" \
  -d '{}'

# 2. Принудительно пересобрать mart
bq mk --transfer_run \
  --run_time=$(date -u +%Y-%m-%dT%H:%M:%SZ) \
  projects/420804682491/locations/asia-east1/transferConfigs/6a1f9418-0000-276f-a1e4-d4f547ee7418
```

**18.3.** ⚠️ Если встретишь max_weight > 50 кг для единицы косметики — вероятно ошибка ввода (вес коробки/паллеты вместо единицы товара). Сообщить заказчику для исправления в МойСкладе.

---

## 19. CF упала с FileNotFoundError bq *(найдено и исправлено в `cf-finance`, 2026-06-18 — раздел добавлен в RUNBOOK 2026-06-24)*

**Симптом:** В логах Cloud Run (например, `cf-finance`) — `FileNotFoundError: [Errno 2] No such file or directory: 'bq'`.

**Причина:** Код CF вызывает `subprocess.run(["bq", ...])`, а в среде Cloud Functions gen2 / Cloud Run утилита `bq` не установлена (она есть только в Cloud Shell / на машине разработчика).

**19.1.** Найти в коде функции все вызовы `subprocess` с `bq`.

**19.2.** Заменить:
- Запуск SQL → `google-cloud-bigquery`: `client.query(sql).result()`
- Запуск Scheduled Query / Data Transfer → `google-cloud-bigquery-datatransfer`: `client.start_manual_transfer_runs(...)`

**19.3.** Убедиться, что в `requirements.txt` есть `google-cloud-bigquery` и `google-cloud-bigquery-datatransfer`. Задеплоить функцию.

**19.4.** Smoke-test: вызвать CF вручную, убедиться что шаг с BQ больше не падает.

---

## 20. Расходы массово получают статус Не указана (expand и limit) *(найдено и исправлено в `cf-finance`, 2026-06-18 — раздел добавлен в RUNBOOK 2026-06-24)*

**Симптом:** На дашборде (или напрямую в `core.fact_payments`) исторические или новые данные теряют разбивку по статьям расходов / агентам / проектам — массово "Не указана".

**Причина:** В URL запроса к МойСкладу используется `expand` (например `expand=expenseItem`) вместе с `limit=1000`. При `limit > 100` API МойСклада молча игнорирует `expand`, не возвращая вложенный объект — статья теряется.

**20.1.** Проверить параметр `limit` в коде функции выгрузки для всех запросов, где используется `expand`.

**20.2.** Если `limit > 100` — исправить на `limit=100` (пагинация: `offset += 100`).

**20.3.** Перезапустить историческую проливку (force backfill) за период, где данные были затёрты.

**20.4.** Верифицировать на нескольких документах через хардчек-скрипт (см. §21.2) — `expenseItem.get("name")` должен быть не пустым после исправления `limit`.

---

## 21. Ghost Records Неразнесённое списание висит хотя клиент всё разнёс *(найдено и исправлено в `cf-finance`, 2026-06-18 — раздел добавлен в RUNBOOK 2026-06-24)*

**Симптом:** Клиент утверждает, что разнёс все расходы по статьям в МойСкладе, но на дашборде висит большая сумма "Неразнесённое списание".

**Причина (Ghost Records):** Старая логика ETL-скрипта фильтровала системные статьи расходов на уровне Python во время выгрузки (`if expense_id in EXCLUDE_EXPENSE_IDS: continue`). Если документ изначально был без статьи ("Неразнесённое списание"), он попадал в BQ. Когда клиент позже проставлял статью (например "Перемещение"), скрипт перестаёт выгружать этот документ (он теперь в EXCLUDE-списке) — `MERGE` больше не видит его, и старая запись со статусом "Неразнесённое списание" навсегда зависает в `fact_payments`.

**21.1. Диагностика пайплайна:** Убедиться, что в текущей версии Python-скрипта НЕТ фильтрации `if/continue` по `expense_item_id` на этапе выгрузки. Выгружаться должны ВСЕ платежи без исключений; фильтрация системных статей — только через `DELETE` в BigQuery **после** `MERGE`:
```sql
DELETE FROM `msklad-bi-prod.core.fact_payments`
WHERE expense_item_id IN ('24c0e914-2d8c-11f1-0a80-11b0000c7043', ...)
-- полный список ID — см. EXCLUDE_EXPENSE_IDS в коде пайплайна
```

**21.2. Хардчек конкретного документа** (если пайплайн уже исправлен, а сумма всё равно висит):
```python
import requests
url = f"https://api.moysklad.ru/api/remap/1.2/entity/paymentout/{payment_id}?expand=expenseItem"
r = requests.get(url, headers={"Authorization": f"Bearer {TOKEN}"})
print(r.json().get("expenseItem"))
```
Если `expenseItem` пуст/`None` — статья реально не проставлена в МойСкладе. Частая причина: крупные SWIFT-переводы или переводы на свои счета, которые клиент забывает разнести.

**21.3.** Сформировать список таких документов через хардчек-скрипт и передать клиенту/бухгалтерии для ручного проставления статьи в МойСкладе.

**21.4.** После исправления статьи в МойСкладе — дождаться следующего `MERGE` (или запустить выгрузку вручную). Запись обновится, а не продублируется.

---

## 22. UUID вместо номера документа на дашборде *(новый раздел, 2026-06-24)*

**Симптом:** В таблицах Looker Studio (например, "Закупки / Товары в пути") вместо понятного номера заказа (`00001`) отображается системный UUID (`purchase_order_id`, `position_id`).

**Причина:** При парсинге ответа МойСклад в `cf-facts` извлекался только корневой `id`, без человекочитаемого поля `name`.

**22.1.** Убедиться, что в STG и core-таблице есть поле для имени — если нет, добавить:
```sql
ALTER TABLE `msklad-bi-prod.core.fact_purchases` ADD COLUMN order_name STRING;
```

**22.2.** Пропатчить парсер в `cf-facts`: добавить `order_name = order.get("name")`, прописать поле в схеме загрузки (`bq_ops.py` → `SchemaField("order_name", "STRING")`).

**22.3.** Задеплоить функцию, запустить принудительный бэкфилл за весь период:
```bash
curl -X POST https://cf-facts-xw5u2boozq-de.a.run.app \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $(gcloud auth print-identity-token)" \
  -d '{"mode": "purchases", "window_days": 9999}'
```

**22.4.** Обновить SQL витрины `marts.in_transit` (добавить `order_name` в `SELECT`) и пересобрать Scheduled Query (длинный SQL — только через Python, см. правило М-22 выше).

**22.5.** В Looker Studio: источник данных → Reconnect schema (см. §15) → заменить старый Dimension (`purchase_order_id`) на `order_name`.

**Правило на будущее:** для любой новой сущности МойСклад при парсинге всегда тянуть и `id`, и `name` одновременно (см. правило выше в разделе "Где смотреть, что происходит").

---

## 23. subprocess bq query и redirect ошибка USAGE *(новый раздел, 2026-06-24)*

**Симптом:** Python-скрипт автоматизации отрабатывает без исключения, но BQ-запрос не выполняется — в выводе только справка `USAGE: bq.py ...`.

**Причина:** Символ перенаправления `<` передан как элемент списка аргументов в `subprocess.run` без `shell=True` — оболочка не интерпретирует `<` как redirect, он попадает в `bq` как обычный (невалидный) аргумент:
```python
# НЕПРАВИЛЬНО
subprocess.run(["bq", "query", "--use_legacy_sql=false", "<", "file.sql"])
```

**23.1.** Если это разовый запуск — заменить на нативный клиент:
```python
from google.cloud import bigquery
client = bigquery.Client()
client.query(open("file.sql").read()).result()
```

**23.2.** Если по каким-то причинам нужен именно `bq` CLI — передать команду одной строкой с `shell=True`:
```python
subprocess.run("bq query --use_legacy_sql=false < temp.sql", shell=True)
```

**23.3.** ⚠️ Применимо только там, где `bq` физически установлен (Cloud Shell, локальная машина). Внутри Cloud Functions (gen2) `bq` нет вообще — см. §19.

---

## 24. ReadTimeoutError на тяжёлых эндпоинтах закупки *(новый раздел, 2026-06-24)*

**Симптом:** В логах Cloud Run для `cf-facts` (например, `mode=purchases`):
```
requests.exceptions.ReadTimeout: HTTPSConnectionPool(host='api.moysklad.ru', port=443): Read timed out
```

**Причина:** Эндпоинты с вложенными позициями заказа (`entity/purchaseorder/{id}/positions`) иногда не успевают ответить за дефолтные 30 секунд.

**24.1.** Открыть код функции, найти обёртку для сетевых запросов (обычно `helpers.py`, функция типа `_api_get`).

**24.2.** Изменить `timeout=30` → `timeout=90`. Декораторы ретраев (`tenacity` и т.п.) сами по себе НЕ спасают от `ReadTimeoutError`, если базовый `timeout` мал — нужно менять именно его.

**24.3.** ⚠️ Общий timeout самой Cloud Function (например 540с) трогать отдельно не нужно — 90с укладывается с запасом.

**24.4.** Задеплоить функцию, перезапустить пайплайн (`mode=purchases`), проверить что закупки выгрузились полностью.

---

## 25. Реконсиляция с МойСкладом: числа не совпадают *(новый раздел, 2026-06-24)*

**Симптом:** Заказчик/владелец сообщает, что цифры на дашборде не совпадают с тем, что он видит в интерфейсе МойСклада (любая метрика: выручка, закупки, платежи).

**Причина:** Может быть что угодно — от реального бага ETL до сравнения несопоставимых вещей. Без методологии легко неделю гонять диагностику впустую.

**25.1. НЕ сравнивать наши же таблицы между собой.** `core.*` vs `marts.*` vs LS-виджет — это сравнение A с A, оно проверяет только внутреннюю согласованность пайплайна, НЕ полноту данных относительно МойСклада (правило 34 в PROJECT_REFERENCE).

**25.2. Получить ground truth прямым запросом к `api.moysklad.ru`** за тот же период/скоуп — либо через `entity/<тип документа>` с агрегацией на своей стороне, либо через готовый report-эндпоинт (`report/profit/byproduct` и аналоги — см. §26 о точности этого метода).

**25.3. ⚠️ Если сравниваешь с UI-экспортом (PDF/выгрузка из интерфейса) — ВСЕГДА проверяй фактический период в шапке документа**, не доверяй quick-select виджету периода вслепую. Подтверждённый кейс: владелец выбрал "май" через быстрый выбор периода в отчёте «Прибыльность» — фактически получил диапазон с 30.04 21:00 по 30.06 20:59 (май+июнь, сдвиг из-за локальной таймзоны UTC+3). Разница была почти 2x и чуть не привела к ложному выводу "у нас баг на 124M".

**25.4. Если ground truth подтверждён (период точно совпадает) и всё равно расходится с core/marts** — следующий подозреваемый: мультивалютные документы, см. §26.

**25.5. Если разница есть, но небольшая (<1%)** — скорее всего речь о курсе валюты на дату документа vs текущий курс на момент диагностики, это не баг, а ожидаемый шум.

**25.6. Систематическая проверка лучше единичного примера.** Один товар/документ может случайно совпасть или разойтись — diff по ВСЕМ строкам отчёта (или хотя бы top-N по объёму) против raw-данных надёжнее и быстрее выводит на реальный паттерн.

**25.7. ⚠️ Сравнивать нужно то же самое ПОЛЕ, не только тот же период/масштаб.** В одном документе МойСклада могут быть несколько похожих, но РАЗНЫХ по смыслу денежных полей (например, в отчёте «Заказы поставщикам»: «Сумма» — полная стоимость заказа, «В ожидании» — то, что ещё не получено/не оплачено). Если пайплайн считает «остаток», а для сверки взяли «полную сумму» — расхождение в десятки процентов будет выглядеть как баг, хотя это просто два разных числа. Подтверждённый кейс (TD-RECON-03, 2026-06-25): разница между «Сумма» (82,3M) и «В ожидании» (68,9M) в отчёте МойСклада по статусу «В пути» была принята за «потерянные данные», хотя пайплайн с самого начала считал именно «В ожидании» — и совпадал с ним до копейки. Перед тем как искать баг — убедиться, что сравниваемые числа концептуально означают одно и то же.

**25.8. ⚠️ Одна и та же статья расходов/категория может физически происходить из РАЗНЫХ типов документов МойСклада, не только из ожидаемого.** Платёжный пайплайн (`paymentout`/`cashout`) может в принципе не видеть часть суммы по статье, если эта же статья также используется на документах списания (`entity/loss`) или другом типе документов — тогда сверка с П&Л-отчётом МойСклада (который агрегирует ПО СТАТЬЕ, а не по типу документа) никогда не сойдётся 1:1, сколько ни чини сам платёжный код. Подтверждённый кейс (TD-RECON-04/TD-PNL-RECON-01, 2026-06-25): статьи «Списания», «Маркетинг и реклама», «Прочие расходы» встречались одновременно и на `paymentout`, и на `entity/loss`. Перед тем как искать баг в ETL конкретного типа документа — проверить через прямой API-запрос, не происходит ли расходящаяся сумма с другого типа документа вообще.

---

## 26. Выручка/суммы аномально малы: мультивалютные документы *(новый раздел, 2026-06-24)*

**Симптом:** Суммы по `core.fact_sales_profit`/`fact_purchases`/аналогам в разы (на отдельных позициях — до 90x) меньше, чем показывает МойСклад в UI или в `report/profit/*`. Количество (qty) при этом часто совпадает точно — расходится только сумма.

**Причина:** Аккаунт МойСклад мультивалютный (проверить `GET entity/currency`). Поле `price` в позиции документа — в минорных единицах ВАЛЮТЫ ДОКУМЕНТА, не всегда KGS. Парсер делит на 100, но не умножает на курс документа (`document.rate.value`) для документов в USD/RUB/KZT — отсюда системная недооценка (подтверждённый множитель ≈90x для USD при курсе 90).

**26.1.** Проверить валюты в аккаунте:
```bash
curl --compressed -X GET "https://api.moysklad.ru/api/remap/1.2/entity/currency" \
  -H "Authorization: Bearer $TOKEN"
```
Если default-валюта не единственная — мультивалютность подтверждена, копаем дальше.

**26.2.** Найти 2-3 позиции с подозрительно низкой ценой за штуку (намного ниже каталожной/средней по товару), посмотреть родительский документ:
```python
doc = requests.get(f"{BASE}/entity/demand/{demand_id}", headers=HEADERS).json()
print(doc.get("rate", {}).get("currency", {}).get("meta", {}).get("href"))
```
Если currency ≠ дефолтная (KGS) — гипотеза подтверждена для конкретного примера.

**26.3.** Систематически: сгруппировать raw-позиции по товару (или по документу), посчитать `price*quantity/100` БЕЗ конвертации и сравнить с эталоном (report-эндпоинт или UI с проверенным периодом). Топ расхождений по объёму почти наверняка окажется мультивалютными документами.

**26.4. Фикс в коде** — найти, где считается `price_kgs`/`sum_kgs`/`revenue_kgs` (обычно `fetch_demands.py`/`fetch_returns.py`/`fetch_purchases.py` или аналогичные имена), добавить умножение на курс:
```python
currency_rate = doc.get("rate", {}).get("value") or 1.0  # KGS per currency unit
price_kgs = (pos.get("price", 0) / 100.0) * currency_rate
```
⚠️ Проверить, не извлекается ли `rate`/`currency_rate` УЖЕ где-то в коде, но не используется при расчёте — недоделанный фикс из прошлого выглядит именно так (переменная объявлена, но не умножена).

**26.5. Раскатка зависит от стратегии загрузки таблицы:**
- Full-replace при каждом запуске (проверить комментарии в коде типа "full replace every run") — достаточно поправить формулу и перезапустить, backfill не нужен, следующий прогон сам пересчитает всё верно.
- Incremental/MERGE — нужен полный reload нужного окна после деплоя фикса (`mode=weekly`/`mode=returns` с большим `window_days`, см. §28 про `promote`).

**26.6. ⚠️ Не путать с исходящей конвертацией для инвестора (KGS→USD через `cf-fx`/`dim_fx_rates`).** Это другая, уже работающая задача — конвертирует ИТОГОВУЮ выручку в KGS в доллары для отображения (`revenue_usd`, `margin_usd`). Баг этого раздела — про ВХОДЯЩУЮ конвертацию (цена в документе уже в чужой валюте → нужно перевести в KGS ДО расчёта revenue_kgs). Два разных смысла слова "rate" в одной кодовой базе, легко перепутать при code review.

---

## 27. CF "успешно" прогнала режим, но изменения в коде не применились *(новый раздел, 2026-06-24)*

**Симптом:** `gcloud functions deploy` вернул ошибку (например `does not have file [main.py]`), но последующие `curl`-вызовы к этой же CF всё равно отвечают `{"status": "ok"}` с свежим `run_id`.

**Причина:** Упавший деплой НЕ заменяет активную ревизию — Cloud Run продолжает обслуживать запросы со СТАРЫМ кодом предыдущей ревизии. Прогоны после неудачного деплоя выглядят полностью успешными (свежий timestamp, валидный JSON-ответ), но используют старую логику — если чинили баг в формуле расчёта, баг остался, просто с свежей датой загрузки.

**27.1.** После КАЖДОГО `gcloud functions deploy` — проверять `revision` и `updateTime` в выводе команды (или `gcloud functions describe <CF> --region=<region>`) ПЕРЕД тем, как запускать `curl`-триггеры.

**27.2.** Самая частая причина падения деплоя в этом проекте — `--source=.` указывает не туда. Текущая директория (`pwd`) должна быть ИМЕННО той, где лежит `main.py`, а не родительский каталог или соседняя папка. Проверить: `pwd && ls main.py`.

**27.3.** Если выяснилось, что деплой упал, а триггеры уже были запущены ПОСЛЕ — данные в BQ свежие по `_loaded_at`/timestamp, но логика старая. Повторить ВСЕ триггеры, которые запускались между неудачным и удачным деплоем — иначе при следующей сверке решишь, что фикс не сработал, хотя он просто не доехал до прода.

---

## 28. mode=weekly загрузил данные, а дашборд/core не изменился *(новый раздел, 2026-06-24)*

**Симптом:** `curl ... -d '{"mode": "weekly", ...}'` вернул `"status": "ok"`, `"staging_rows_loaded": N > 0`, но запрос к `core.fact_sales_profit` показывает старые числа.

**Причина:** `mode=weekly` грузит данные только в STAGING (`stg_msklad.fact_sales_staging`). Перенос в `core` делает ОТДЕЛЬНЫЙ режим `mode=promote` (MERGE staging → core, минуя DQ Gate — см. таблицу режимов в PROJECT_REFERENCE раздел 1).

**28.1.** После `mode=weekly` (или любого режима, пишущего в staging) — ОБЯЗАТЕЛЬНО вызвать `mode=promote` с тем же `window_days`:
```bash
curl -X POST https://cf-facts-xw5u2boozq-de.a.run.app \
  -H "Authorization: Bearer $(gcloud auth print-identity-token)" \
  -d '{"mode": "promote", "window_days": 90}'
```

**28.2.** Проверить ответ `promote` на `merge_stats.affected_rows` — если 0 или сильно меньше `staging_rows`, что-то не так с MERGE-условием, не просто "забыли promote".

**28.3.** ⚠️ `promote` явно документирован как пропускающий DQ Gate — если ожидал блокировку аномального роста выручки (после фикса данные могут резко вырасти, это нормально) и её не было, это не ошибка, а ожидаемое поведение этого режима. DQ Gate применяется к `hourly`, не к `promote`.

---

## 29. Mart показывает старые цифры, хотя core уже обновился *(новый раздел, 2026-06-25)*

**Симптом:** Дашборд/виджет на марте показывает заметно меньшее число, чем ожидается после фикса в core. SQ марта при этом не падает (`bq ls --transfer_run` показывает только `SUCCEEDED`).

**Причина:** Mart обновляется по СВОЕМУ расписанию (например, раз в сутки в фиксированное время), независимо от того, когда обновился core. Если фикс/backfill в core прилетел ПОСЛЕ времени последнего прогона SQ за сегодня — следующий штатный прогон (завтра в то же время) сам всё поправит. Это не сбой автоматизации, а обычный временной лаг между слоями.

**29.1.** Сравнить два timestamp:
```sql
-- core
SELECT MAX(_loaded_at) FROM `msklad-bi-prod.core.<table>`;
-- mart
SELECT MAX(_mart_refreshed_at) FROM `msklad-bi-prod.marts.<mart>`;
```
Если `_mart_refreshed_at` РАНЬШЕ, чем `_loaded_at` в core — это и есть причина, переходи к 29.2.

**29.2.** Проверить историю запусков SQ за последние 5-10 дней:
```bash
bq ls --transfer_run --max_results=10 \
  "projects/420804682491/locations/asia-east1/transferConfigs/{CONFIG_ID}"
```
Если все `SUCCEEDED` — автоматику не трогать, дело не в ней.

**29.3.** Если нужно поправить дашборд НЕМЕДЛЕННО, не дожидаясь штатного прогона — выполнить канонический SQL марта вручную через `bigquery.Client().query(sql)` (см. PROJECT_REFERENCE §4.3 за актуальным SQL конкретного марта). Это идемпотентно (`CREATE OR REPLACE`) и не трогает сам SQ/расписание.

**29.4.** ⚠️ При сверке результата с эталоном МойСклада — убедиться, что эталон считает то же самое поле, что и mart (см. §25.7). Расхождение, которое на первый взгляд выглядит как "ещё не доехало", может быть сравнением `Сумма` против `В ожидании` или аналогичной парой похожих, но разных полей.

---

## 30. CF таймаутит каждую ночь без видимых алертов *(новый раздел, 2026-06-25)*

**Симптом:** Данные за последние N дней не обновляются, хотя Cloud Scheduler формально "ENABLED" и `lastAttemptTime` свежий каждую ночь. Алерта на сам факт сбоя планировщика нет (есть только обычный мониторинг 5xx на стороне Cloud Run, если он настроен).

**Причина:** CF превышает `--timeout`, Cloud Scheduler фиксирует это как `status.code=2` (`UNKNOWN`) с `debugInfo: REJECTED_DEADLINE_EXCEEDED`, и если `retryConfig.maxRetryDuration=0s` — повторных попыток нет. Внешне это выглядит как "джоб вроде есть, но почему-то не помогает".

**30.1.** Проверить состояние и историю Scheduler-джоба:
```bash
gcloud scheduler jobs describe <job-name> --location=<region> --project=<project>
```
Смотреть на `status.code` (2 = UNKNOWN, обычно таймаут/сетевая проблема) и `retryConfig.maxRetryDuration`.

**30.2.** Найти точный текст ошибки в логах Cloud Run (НЕ logging для scheduler job — это разные ресурсы):
```bash
gcloud logging read \
  'resource.type="cloud_run_revision" AND resource.labels.service_name="<cf-name>" AND severity>=ERROR' \
  --project=<project> --limit=10 --format=json
```
`httpRequest.status=504` + `latency` около значения `--timeout` — таймаут подтверждён.

**30.3.** Если причина — объём данных растёт, а функция делает полный re-fetch без инкрементального окна при каждом запуске (см. §41 в PROJECT_REFERENCE) — поднять `--timeout` (например, до `1800s`, по аналогии с `cf-facts`) как немедленный фикс, и завести отдельную задачу на инкрементальную загрузку как структурное решение (поднятие таймаута не масштабируется бесконечно).

**30.4.** Добавить `retryConfig` со значением `maxRetryDuration` > 0 на сам Scheduler-джоб, чтобы единичный сетевой сбой не превращался в "тихий" пропуск целой ночи без какой-либо повторной попытки.

---

## 31. CF падает 500 на необязательном шаге после успешной загрузки *(новый раздел, 2026-06-25)*

**Симптом:** Ручной `curl` к CF возвращает `500 Internal Server Error`. При этом проверка данных в BQ (`MAX(_loaded_at)`) показывает, что данные ЗА ЭТОТ ЗАПУСК всё-таки загрузились свежими.

**Причина:** Функция выполняет несколько последовательных шагов (загрузка → MERGE → опциональный побочный шаг, например форс-триггер марта). Если последний шаг падает необработанным исключением, Flask/functions-framework возвращает 500 для ВСЕГО запроса — но шаги ДО краша уже закоммичены в BQ (MERGE — отдельная завершённая транзакция, она не откатывается тем, что упало позже в том же процессе).

**31.1.** Получить полный traceback (не просто факт ERROR — сам текст исключения):
```bash
gcloud logging read \
  'resource.type="cloud_run_revision" AND resource.labels.service_name="<cf-name>"' \
  --project=<project> --limit=20 --freshness=10m \
  --format="table(timestamp,severity,textPayload)"
```
Если в той же функции реальный traceback не попадает в `jsonPayload.message` — смотреть `textPayload`, часто туда падают необработанные Python-трейсбэки в Cloud Run gen2.

**31.2.** По traceback определить, ДО или ПОСЛЕ основной работы (загрузка/MERGE) произошёл краш — смотреть порядок `print()`-сообщений в логе непосредственно перед traceback. Если "Loading...", "Running MERGE..." уже были — данные в безопасности, краш в последующем шаге не критичен для целостности данных.

**31.3.** Изолировать необязательный шаг через `try/except`, чтобы его сбой не превращал успешную загрузку данных в HTTP 500 (и не путал мониторинг/алерты):
```python
try:
    optional_step()
except Exception as e:
    print(f"WARNING: optional_step() failed (non-fatal): {e}")
```

**31.4.** ⚠️ Это лечит СИМПТОМ (ложный 500), не причину сбоя самого необязательного шага (например, недостающие IAM-права). Решить отдельно: либо выдать нужные права, либо, если шаг дублирует то, что уже происходит само по расписанию (см. §29) — просто убрать вызов, не патчить права.

---

## 32. Патч кода через терминал Cloud Shell ломается *(новый раздел, 2026-06-25)*

**Симптом:** Правка `main.py` (или любого файла) через копирование текста в терминал Cloud Shell даёт неожиданный результат: файл обрезан/перемешан, патч-скрипт дублирует уже применённое изменение, `py_compile` падает с `IndentationError` после, казалось бы, простой правки.

**Причины (несколько независимых, часто встречаются вместе):**
1. Веб-терминал Cloud Shell ненадёжен при вставке большого многострочного блока (heredoc `cat << 'EOF'` и аналоги) — вставка может обрываться/перемешиваться.
2. **Traceback в Python ВСЕГДА показывает нормализованный отступ строки (обычно 4 пробела), независимо от реального отступа в файле.** Патч-скрипт, написанный на основе отступа из traceback, будет искать неправильную строку.
3. Патч по подстроке (`if old_str in content: content.replace(...)`) не идемпотентен: если результат замены содержит исходный паттерн как часть себя (например, обёртка `"    foo()"` в `try:` даёт `"        foo()"`, которая всё ещё содержит `"    foo()"` как подстроку) — повторный запуск того же скрипта патчит уже патченное, давая дубль.

**32.1.** Для доставки файла в Cloud Shell — НЕ вставлять многострочный код в терминал. Использовать:
- Upload: иконка «⋮» в терминале → Upload → файл попадёт в `$HOME`, затем `mv` в нужную папку
- Cloud Shell Editor: `cloudshell edit <file>` — графический редактор, вставка туда не проходит через bash
- Если нужна именно команда — одна физическая строка без вложенных переносов (`python3 -c '...'`, многострочность только через `\n` как escape-последовательность ВНУТРИ строки)

**32.2.** Перед ЛЮБОЙ правкой существующего файла — прочитать его ПОЛНОСТЬЮ (`cat -n file.py`), не патчить по фрагменту из traceback или grep с маленьким контекстом. Реальный отступ и структуру кода нужно увидеть, а не предполагать.

**32.3.** Патчить по точным номерам строк (`lines[N]`, проверенным заранее через `sed -n` или `cat -n` по тому же файлу) либо по ПОЛНОМУ содержимому строки (`line.strip() == "..."`), не по вхождению подстроки. Перед тем как давать команду пользователю — проверить её на синтетической копии, воспроизводящей точную структуру (номера строк, отступы) реального файла.

**32.4.** После любой правки — несколько независимых проверок, не одна:
```bash
python3 -m py_compile main.py   # синтаксис
python3 -c "import ast; ast.parse(open('main.py').read())"   # структура
tail -5 main.py                 # файл не обрублен
```

---

## 33. Верификация долгого ручного вызова CF *(новый раздел, 2026-06-25)*

**Симптом:** Запустил `curl -X POST` к CF вручную из терминала Cloud Shell, консоль "висит" без вывода заметно дольше обычного, потом можно вводить следующую команду без какого-либо статуса/ответа на экране.

**Причина:** Если CF реально выполняется дольше 1-2 минут (например, полный re-fetch большого объёма данных), интерактивная сессия Cloud Shell может потерять/не показать ответ — это проблема терминала, не сервера. Сам HTTP-запрос и обработка на стороне Cloud Run при этом продолжаются независимо от того, слушает ли клиент ответ.

**33.1.** Для вызовов длиннее 1-2 минут — запускать в фоне, не дожидаясь в foreground:
```bash
nohup curl -X POST <CF_URL> \
  -H "Authorization: Bearer $(gcloud auth print-identity-token)" \
  -o /tmp/cf_response.txt -w "HTTP_STATUS:%{http_code}\n" \
  > /tmp/cf_curl.log 2>&1 &
disown
```
Можно вводить другие команды, закрывать вкладку — процесс продолжит работу на VM Cloud Shell.

**33.2.** Проверять результат НЕ через терминальный вывод, а через слой данных — это работает независимо от того, что показал (или не показал) клиент:
```sql
SELECT MAX(_loaded_at) AS last_loaded, COUNT(*) AS row_count
FROM `msklad-bi-prod.core.<table>`;
```
Свежий `_loaded_at` = функция отработала, вне зависимости от статуса curl на экране.

**33.3.** ⚠️ Если до этого был "подвисший" foreground-вызов и теперь запущен ещё один в фоне — проверить, не работают ли оба параллельно (гонка на `WRITE_TRUNCATE` в staging-таблицу):
```bash
gcloud logging read '...' --freshness=30m | grep -E "Loading|Running MERGE"
```
Если виден ОДИН проход за нужное окно — гонки нет. Если больше одного — дождаться завершения обоих, перепроверить итоговые данные.

**33.4.** Прочитать лог фонового вызова в любой момент:
```bash
cat /tmp/cf_curl.log /tmp/cf_response.txt 2>/dev/null
```

---

## Эскалация

Если ничего из Runbook не помогло:

1. Собери диагностический пакет:
   - Текст ошибки с traceback
   - Timestamp инцидента (UTC)
   - Имя упавшего CF / workflow шага
   - Вывод `gcloud workflows executions describe` с `--format="json(error)"`
   - Что уже попробовал из Runbook

2. Контакты:
   - **Ilyas Bazarov** (owner): Telegram @ilyasbazarov
   - **support@moysklad.ru**: Техподдержка МойСклада
   - **Bakai Bank Call-центр**: +996 (312) 61-00-61 (по вопросам FX API)
   - **GCP Support**: https://cloud.google.com/support

3. **Правило:** не делай ничего деструктивного при уверенности < 100%.

---

## Приложение A: IAM checklist — роли etl-sa

| Роль | Зачем |
|---|---|
| `roles/bigquery.dataEditor` | Запись в BQ |
| `roles/bigquery.jobUser` | Запуск BQ jobs |
| `roles/storage.objectCreator` | Запись в GCS |
| `roles/storage.objectViewer` | Чтение из GCS |
| `roles/secretmanager.secretAccessor` | Чтение msklad-token и bakai-fx-token |
| `roles/run.invoker` | Вызов Cloud Run сервисов |
| `roles/logging.logWriter` | Запись логов |

**⚠️ (2026-06-25) Отсутствует:** роль для `BigQuery Data Transfer API` (`start_manual_transfer_runs`). `cf-finance` пытается форсировать `sq_marts_expenses` через этот API и падает `PermissionDenied` (см. RUNBOOK §31, TD-CF-FINANCE-PERMS-01 в PROJECT_REFERENCE). Сейчас не блокирует работу (вызов обёрнут в `try/except`), но если решат выдавать права — точную минимально достаточную роль смотреть по ссылке из самого текста ошибки (`https://cloud.google.com/bigquery/docs/working-with-transfers#required_roles_2`), не угадывать заранее.

---

## Приложение B: Периодические проверки (раз в неделю)

Понедельник утром (~15 минут):

- [ ] Все Workflow за прошлую неделю — зелёные?
- [ ] Свежесть: `MAX(transaction_date)` не старше 2 часов?
- [ ] DQ Gate за неделю не падал?
- [ ] **FX-курсы:** cf-fx отработал вчера (`source: bakai_bank_api` в логах, lag = 0)?
- [ ] Audit-snapshots dim'ов делаются ежедневно?
- [ ] Telegram-алерты доходят?
- [ ] Марты обновлялись сегодня?
- [ ] BQ траты в пределах ожидаемого?
- [ ] **Weight покрытие** растёт? (ежемесячно) `COUNTIF(weight > 0) / COUNT(*)` в dim_products
- [ ] **Scheduler-джобы без ретраев** (`finance-daily-update` и аналоги с `retryConfig.maxRetryDuration=0s`) — реально ли отработали успешно за последнюю неделю, не только "ENABLED"? `gcloud scheduler jobs describe <job>` → `status.code` должен быть пустым/успешным на последнем запуске, не `2 (UNKNOWN)`

---

## Журнал инцидентов

| Дата | Симптом | Раздел | Что сделал | Что помогло | Время |
|---|---|---|---|---|---|
| 2026-05-11 | mode=returns отсутствовал в main.py | §1.8 | Реализован mode=returns, ревизия 3 | Реализация + деплой | 2ч |
| 2026-05-11 | fact_returns: 62 → 10 строк после smoke-test | §1 | window_days=730 | window_days=730 | 15 мин |
| 2026-05-11 | marts.gmroi no_inventory=100% | §9 аналог | BQ UPDATE + патч _parse_href | split("?")[0] | 1ч |
| 2026-05-12 | product_folder=NULL у всех товаров | §9 аналог | _fetch_folder_map() в cf-dim | Отдельный запрос к productfolder | 2ч |
| 2026-05-13 | FX lag > 3 дня (выходные) | §13 | forward-fill 4 строки + tolerance 5d | INSERT + revision 00012-waj | 20 мин |
| 2026-05-18 | **М-19:** dim_fx_rates lag 7 дней → FAILED | §13 | forward-fill 7 строк | INSERT forward-fill | 5 мин |
| 2026-05-18 | **М-20:** DQ drift false positive (воскресенье) | §14/§2.6 | Manual promote window=90 | curl cf-facts promote | 20 мин |
| 2026-05-18 | **М-21:** LS графики сломались после rebuild | §15 | Reconnect data source в LS | Schema refresh | 2 мин |
| 2026-05-18 | **М-22:** SQ создана с обрезанным SQL (heredoc) | — | Python + bq update --transfer_config | Python open().write() | 5 мин |
| 2026-05-18 | **М-23:** DQ weekday false positive (161K vs MA 1.29M) | §3 | DQ_DRIFT_THRESHOLD 0.30→0.10, деплой cf-dq | Порог 10% | 15 мин |
| 2026-05-21 | **М-24:** freshness lag=2 + FX lag=7 → 10ч FAILED | §16+§13 | Патч cf-dq (FRESHNESS→3), forward-fill, manual promote | Оба фикса вместе | 40 мин |
| 2026-06-03 | **М-25:** CF-FX мигрирован с НБКР XLS → Bakai Bank API | TD-CF-FX | Полный редеплой cf-fx, новый секрет bakai-fx-token | Bakai OpenBanking API, MERGE | 3ч |
| 2026-06-03 | **М-26:** Bakai API 415 при curl с Content-Type на GET | §6 аналог | Убрать Content-Type из GET запросов; использовать Python requests | Python requests без Content-Type header | 20 мин |
| 2026-06-03 | **М-27:** Bakai token 401 после auth — требовалась активация банком | §17 | Связались с банком, банк активировал через ЛК | Активация на стороне банка | 1ч |
| 2026-06-03 | **М-28:** FX lag 7 дней перед деплоем cf-fx | §13 | forward-fill 7 строк через BQ INSERT | Стандартный forward-fill | 5 мин |
| 2026-06-18 | **М-29:** CF упала, `FileNotFoundError: bq` (cf-finance) | §19 | Переход с `subprocess`+`bq` на `google-cloud-bigquery`/`-datatransfer` | Нативные клиенты вместо CLI | — |
| 2026-06-18 | **М-30:** expand+limit=1000 → expenseItem=NULL → "Не указана" массово (cf-finance) | §20 | `limit` зафиксирован на 100 при `expand`, backfill | Лимит 100 | — |
| 2026-06-18 | **М-31:** Ghost Records — "Неразнесённое списание" не уходило после исправления в МойСкладе (cf-finance) | §21 | Фильтрация перенесена с Python (`if/continue`) на `DELETE` после `MERGE` в BQ | DELETE-постфильтр | — |
| 2026-06-18 | **М-35:** Деплой `cf-finance` (gen2) + Cloud Scheduler `finance-daily-update`, замена standalone `load_payments.py` | §21, Раздел "Архитектура" | `gcloud functions deploy` + `gcloud scheduler jobs create http` | Revision cf-finance-00001-wiv | ~5 мин |
| 2026-06-24 | **М-32:** UUID вместо номера заказа на дашборде "Закупки в пути" | §22 | Добавлено поле `order_name` (схема + парсер cf-facts + backfill + mart + LS reconnect) | id+name mapping standard | — |
| 2026-06-24 | **М-33:** `subprocess.run` bq query с `<` → ошибка USAGE | §23 | `shell=True` / переход на native client | Один из двух фиксов | — |
| 2026-06-24 | **М-34:** `ReadTimeoutError` на cf-facts mode=purchases | §24 | `timeout=30` → `timeout=90` в сетевой обёртке | timeout 90s | — |
| 2026-06-24 | **М-36:** TD-SEC-01 — `cf-finance` подтверждена как баг (allow-unauthenticated) | TD-SEC-01 (PROJECT_REFERENCE) | Зафиксировано владельцем, перенесено в TD backlog P1 | Owner sign-off | — |
| 2026-06-24 | **М-37 (главный инцидент сессии):** Выручка май не билась с МойСкладом (177M vs 54M на дашборде) | §25, §26 | (1) UI quick-select периода реально захватывал май+июнь — не баг; (2) найден реальный баг: `price_kgs` не умножался на курс валюты документа в `fetch_demands.py`/`fetch_returns.py`/`fetch_purchases.py` — пофикшено, deploy `cf-facts-00007-xir`, прогнаны `weekly`→`promote`/`purchases`/`returns` | Конвертация по `rate.value` | ~6ч (вся сессия) |
| 2026-06-24 | **М-38:** Деплой `cf-facts` упал (`--source=.` не туда), но 3 прогона режимов после этого вернули `status:ok` со старым кодом | §27 | `cd` в правильную директорию перед деплоем, повторные прогоны после успешного деплоя | Проверка revision/updateTime перед триггером | 20 мин |
| 2026-06-25 | **М-39:** «В пути» на дашборде 1,2M vs МойСклад 82M+ (TD-RECON-03) | §25.7, §29 | (1) Построчная сверка `core.fact_purchases` с МойСклад «В ожидании» — 13/13 совпало, гипотеза `window_days=90` опровергнута; (2) найдена истинная причина — `marts.in_transit` не пересобрался после фикса (SQ ежедневно 13:09 UTC, фикс в core 22:01 UTC) | `CREATE OR REPLACE marts.in_transit` вручную | ~1ч |
| 2026-06-25 | **М-40:** `cf-finance` таймаутит 504 каждую ночь с 06-19, Scheduler без ретраев это скрывал (TD-RECON-04) | §30 | Обнаружено через freshness-by-month (все 12 месяцев загружены в одно узкое окно 06-19 = разовый годовой backfill, не инкремент) + `gcloud scheduler jobs describe` + `gcloud logging read` (httpRequest.status=504, latency≈300s) | `--timeout=300s` → `1800s`, redeploy | ~1ч |
| 2026-06-25 | **М-41:** После фикса таймаута — `cf-finance` падает 500 на `trigger_marts()` (`PermissionDenied` на `sq_marts_expenses`) уже ПОСЛЕ успешного MERGE (TD-RECON-04) | §31 | Полный traceback из логов подтвердил порядок (Loading→MERGE→DELETE→краш); `try/except` вокруг `trigger_marts()` | try/except, redeploy `cf-finance-00006-piv` | ~30 мин (+ время на серию неудачных попыток патча, см. М-42) |
| 2026-06-25 | **М-42:** Серия неудачных попыток патча `main.py` — heredoc-вставка ломалась, патч-скрипт по подстроке дал дубль/битые отступы (traceback показывал 4 пробела, реальный отступ — 8) | §32 | Переход на: полное чтение файла (`cat -n`) → патч по точным номерам строк одной физической `python3 -c` строкой → тест на синтетической копии ДО выдачи → `py_compile`+`ast.parse`+`tail` после | Line-indexed патч + множественная верификация | ~40 мин |
| 2026-06-25 | **М-43:** Ручной `curl` к `cf-finance` "висит" без вывода в Cloud Shell (полный прогон ~13 мин) | §33 | `nohup ... & disown` в фоне; верификация через `MAX(_loaded_at)` в BQ вместо терминального вывода; проверка на гонку между старым "подвисшим" и новым фоновым вызовом через grep по логам | nohup + BQ-верификация | ~15 мин |
| 2026-06-25 | **М-44:** 4 статьи П&Л («Списания», «Комиссия», «Неразнесенное списание», «Обучение», ~85,6% разрыва) отсутствуют в `fact_payments` даже на свежих данных — заведено как TD-PNL-RECON-01 | §25.8 | Опровергнута гипотеза заморозки (свежая перезагрузка дала идентичный результат); проверка `applicable=false` (0/0, отклонено); проверка `entity/loss` — нашлись 3 из 4 статей, но арифметика не сходится 1:1 (Списания +9x, Маркетинг +38%, Прочие −31%) | Не закрыто — методология агрегации П&Л не установлена | ~1ч, продолжение в следующей сессии |

---

**Версия 8.0** | Обновлён: 2026-06-25  
_Документ — живой. Каждый новый инцидент = новая запись в Журнале._
