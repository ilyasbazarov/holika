# RUNBOOK: BI-пайплайн МойСклад → BigQuery → Looker Studio

**Версия:** 2.0  
**Обновлён:** 2026-05-15 (День 4, Неделя 3) — добавлены: архитектура, TD-07 (jsonPayload.message), §13 FX forward-fill, IAM-чеклист  
**Предыдущая версия:** 1.0 (стартовая, Неделя 2)

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
│  cf-fx    (daily)                                 │  mode=returns → 730d TRUNCATE
│  cf-inventory (daily 03:00 KGT snapshot)          │
│  cf-dq    (DQ Gate, вызывается из workflow)       │
│  cf-alert (webhook для Telegram алертов)          │
└───────────────────────────────────────────────────┘
        │ raw JSON (immutable)         │ BQ loads
        ▼                              ▼
  GCS: msklad-raw/             BigQuery: msklad-bi-prod
  (lifecycle 365 дней)         ├── stg_msklad (TTL 14d)
                                ├── core
                                │   ├── fact_sales_profit   (30K+ строк)
                                │   ├── fact_returns        (62+ строк)
                                │   ├── fact_inventory      (1448 строк)
                                │   ├── fact_purchases      (~5K строк)
                                │   ├── dim_products        (4463 строк)
                                │   ├── dim_counterparties  (5220 SCD2)
                                │   ├── dim_employees
                                │   ├── dim_fx_rates
                                │   └── dim_metadata_mappings
                                ├── marts (Scheduled Queries, каждые 24ч)
                                │   ├── sales_overview
                                │   ├── inventory_health
                                │   ├── gmroi + gmroi_by_folder
                                │   └── abc_xyz
                                └── _backup (TTL 30d)
                                         ▼
                                  Looker Studio (3 страницы)
                                  ├── Инвестор KGS
                                  ├── Склад
                                  └── Операционка
```

**Расписание запусков:**

| Компонент | Расписание | Оркестрация |
|---|---|---|
| msklad-pipeline-hourly | каждый час | Cloud Scheduler → Cloud Workflows |
| msklad-pipeline-weekly | воскресенье 01:00 UTC | Cloud Scheduler → Cloud Workflows |
| CF-Dim | ежедневно 03:00 KGT (20:00 UTC prev day) | Cloud Scheduler → CF напрямую |
| Marts SQ | ежедневно | BigQuery Scheduled Queries |

---

## Быстрый индекс

| Симптом / алерт | Раздел |
|---|---|
| Алерт "CF упала" / 5xx ошибка | [1. Cloud Function упала](#1-cloud-function-упала) |
| Алерт "DQ Gate провалился" | [2. DQ Gate провалился](#2-dq-gate-провалился) |
| Алерт "выручка вчера < 30% от 7-day MA" | [3. Drift по выручке](#3-drift-по-выручке) |
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
| НБКР не публиковал курс / FX lag > 3 дня | [13. FX-курсы отсутствуют (НБКР)](#13-fx-курсы-отсутствуют-нбкр) |

---

## Где смотреть, что происходит

### Логи Cloud Functions (TD-07 fix — jsonPayload.message)

⚠️ **Важно:** CF gen2 пишут структурированные логи через Python `logging`. В Cloud Logging они
приходят как `jsonPayload`, а не `textPayload`. Фильтровать нужно по `jsonPayload.message`, иначе
ничего не найдёшь.

**В UI (Cloud Logging → Log Explorer):**
```
resource.type="cloud_run_revision"
resource.labels.service_name="cf-facts"
jsonPayload.message=~"ERROR|FAILED|exception"
```

Заменить `cf-facts` на нужную функцию: `cf-dim`, `cf-inventory`, `cf-dq`, `cf-alert`.

**Через CLI (правильный способ):**
```bash
# Последние 50 ERROR-логов от cf-facts
gcloud logging read \
  'resource.type="cloud_run_revision" AND resource.labels.service_name="cf-facts" AND severity>=ERROR' \
  --project=msklad-bi-prod \
  --limit=50 \
  --format="table(timestamp,jsonPayload.message)"

# Логи за конкретный прогон (найти по timestamp из Workflow execution)
gcloud logging read \
  'resource.type="cloud_run_revision" AND resource.labels.service_name="cf-facts" AND timestamp>="2026-05-15T10:00:00Z" AND timestamp<="2026-05-15T11:00:00Z"' \
  --project=msklad-bi-prod \
  --format="table(timestamp,severity,jsonPayload.message)"
```

**❌ Не работает (старый формат):**
```bash
# НЕ ИСПОЛЬЗУЙ — вернёт пусто для gen2 функций
gcloud functions logs read cf-facts --limit 50 --region=asia-east1
```

### Логи Cloud Workflows
```
GCP Console → Workflows → [имя workflow] → Executions → [последний execution] → Steps
```

Или для поиска FAILED:
```bash
gcloud workflows executions list msklad-pipeline-hourly \
  --project=msklad-bi-prod \
  --location=asia-east1 \
  --filter="state=FAILED OR state=CANCELLED" \
  --limit=10
```

### Состояние BQ таблиц

```sql
-- Свежесть данных
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
SELECT 'dim_fx_rates', MAX(date), COUNT(*)
FROM `msklad-bi-prod.core.dim_fx_rates`;

-- Строки пришедшие за последние 2 часа
SELECT COUNT(*), MAX(_loaded_at) AS last_load
FROM `msklad-bi-prod.core.fact_sales_profit`
WHERE _loaded_at >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 2 HOUR);
```

### Состояние GCS raw
```bash
gsutil ls -l gs://msklad-raw/profitability/ | sort -k2 | tail -20
```

---

## 1. Cloud Function упала

**Симптом:** Алерт "msklad-cf-error" / статус `Failed` в Cloud Functions UI.

### Шаги

**1.1.** Открой логи упавшей функции (см. [Где смотреть — TD-07 fix](#где-смотреть-что-происходит)).

**1.2.** Найди последнюю строку с severity `ERROR` или `CRITICAL`. Скопируй текст ошибки.

**1.3.** Сопоставь с таблицей:

| Текст в ошибке | Куда дальше |
|---|---|
| `429 Too Many Requests` | [6. Проблемы с API МойСклад](#6-проблемы-с-api-мойсклад) |
| `503` / `502` / `504` | [6. Проблемы с API МойСклад](#6-проблемы-с-api-мойсклад) |
| `Memory limit exceeded` | Шаг 1.4 |
| `Function execution took longer than ... ms` | Шаг 1.5 |
| `Could not get secret` / `permission denied` | Шаг 1.6 |
| `BigQuery: ... already exists` / `MERGE conflict` | Шаг 1.7 |
| `KeyError` / `TypeError` / `JSONDecodeError` | Шаг 1.8 |
| `dim_fx_rates устарела` | [13. FX-курсы отсутствуют](#13-fx-курсы-отсутствуют-нбкр) |
| Ничего из этого | Шаг 1.9 |

**1.4. Memory limit exceeded (CF OOM):**
```bash
# Посмотреть текущий лимит памяти
gcloud run services describe cf-facts --region=asia-east1 --project=msklad-bi-prod \
  --format="value(spec.template.spec.containers[0].resources.limits.memory)"

# Обновить до 2GB (если было 1GB) или 4GB (если было 2GB)
gcloud functions deploy cf-facts \
  --gen2 --runtime=python312 --region=asia-east1 \
  --source=cf/cf_facts --entry-point=main \
  --service-account=etl-sa@msklad-bi-prod.iam.gserviceaccount.com \
  --memory=2048MB --timeout=540s \
  --set-secrets="MSKLAD_TOKEN=msklad-token:latest" \
  --trigger-http
```
После деплоя — вызови CF вручную. Если снова OOM при 4GB — это структурная проблема, эскалация.

**1.5. Timeout:**
```bash
# Проверь размер последнего raw-файла
gsutil ls -l "gs://msklad-raw/profitability/$(date +%Y-%m-%d)/" | awk '{print $1}' | sort -n | tail -1
```
Если размер > 2x от обычного — МойСклад отдаёт больше данных, нужно увеличить timeout:
```bash
# Увеличить timeout до 1800s (30 мин) — максимум для gen2 HTTP
gcloud functions deploy cf-facts ... --timeout=1800s
```

**1.6. Secret Manager / permission denied:**
```bash
# Проверить что у etl-sa есть доступ к секрету
gcloud secrets get-iam-policy msklad-token --project=msklad-bi-prod

# Если нет — добавить
gcloud secrets add-iam-policy-binding msklad-token \
  --member="serviceAccount:etl-sa@msklad-bi-prod.iam.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor" \
  --project=msklad-bi-prod

# Если токен МойСклад истёк (401 в логах) — обновить
echo -n "NEW_TOKEN_HERE" | gcloud secrets versions add msklad-token \
  --data-file=- --project=msklad-bi-prod
```

**1.7. BigQuery MERGE conflict / staging:**
```bash
bq query --use_legacy_sql=false --project_id=msklad-bi-prod \
  'TRUNCATE TABLE `msklad-bi-prod.stg_msklad.fact_sales_staging`'
```
Затем перезапусти CF вручную через Test the function.

**1.8. Ошибка парсинга (KeyError/JSONDecodeError):**
```bash
# Скачать последний raw JSON для отладки
gsutil cp "gs://msklad-raw/profitability/$(date +%Y-%m-%d)/*.json.gz" /tmp/
gunzip /tmp/*.json.gz
python3 -c "import json; d=json.load(open('/tmp/<filename>.json')); print(list(d.keys()))"
```
Сравни структуру с ожидаемой в коде. **Не правь код в проде** — изменение → репо → деплой.
На время фикса — приостанови Scheduler:
```bash
gcloud scheduler jobs pause msklad-pipeline-hourly-trigger --location=asia-east1
```

**1.9. Неизвестная ошибка:**
Вызови CF вручную с полным payload. Если повторилась — собери пакет для эскалации (см. раздел [Эскалация](#эскалация)).

**1.10. После починки:**
```bash
# Убедиться что данные доехали
bq query --use_legacy_sql=false --project_id=msklad-bi-prod \
  'SELECT MAX(transaction_date), MAX(_loaded_at) FROM `msklad-bi-prod.core.fact_sales_profit`'
```
Запиши инцидент в [Журнал](#журнал-инцидентов).

---

## 2. DQ Gate провалился

**Симптом:** Алерт "msklad-dq-gate-failed".

DQ Gate защищает core от плохих данных. Когда он падает — это **сигнал, что данные кривые**, не баг пайплайна. Нельзя просто отключить чек — сначала понять причину.

### Шаги

**2.1.** Открой логи cf-dq → найди какой именно чек провалился:

| Чек | Что значит | Куда дальше |
|---|---|---|
| `len(df) == 0` | API вернул пустой массив | Шаг 2.2 |
| `revenue drift > 50%` | Выручка резко упала/выросла | [3. Drift по выручке](#3-drift-по-выручке) |
| `FK integrity` | product_id / agent_id не в dim'ах | Шаг 2.3 |
| `freshness` | MAX(transaction_date) старше 1 дня | [4. Данные не свежие](#4-данные-не-свежие) |
| `margin sanity` | Маржа > 100% выручки | Шаг 2.4 |
| `currency normalization` | Суммы в тыйынах (не делились на 100) | Шаг 2.5 |

**2.2. Пустой ответ API:**
- Зайди руками в МойСклад UI → проверь продажи за сегодня.
- Если в МойСкладе продажи есть, а API пусто → [6. Проблемы с API](#6-проблемы-с-api-мойсклад).
- Если в МойСкладе пусто — нормально (выходной, нет транзакций). Никаких действий.

**2.3. FK integrity — неизвестный product_id или agent_id:**
```sql
-- Какие product_id "висят" без dim
SELECT DISTINCT f.product_id
FROM `msklad-bi-prod.stg_msklad.fact_sales_staging` f
LEFT JOIN `msklad-bi-prod.core.dim_products` d ON f.product_id = d.product_id
WHERE d.product_id IS NULL LIMIT 20;
```
Если нашлись → новый товар в МойСкладе, cf-dim ещё не успел подтянуть. Запусти cf-dim вручную:
```bash
curl -s -X POST https://cf-dim-xw5u2boozq-de.a.run.app \
  -H "Authorization: Bearer $(gcloud auth print-identity-token)" \
  -H "Content-Type: application/json" \
  -d '{"mode": "full"}' | python3 -m json.tool
```
После завершения перезапусти cf-facts.

**2.4. Margin sanity — маржа > 100%:**
```sql
SELECT product_id, revenue_kgs, cogs_kgs, margin_kgs,
  margin_kgs / NULLIF(revenue_kgs, 0) AS margin_pct
FROM `msklad-bi-prod.stg_msklad.fact_sales_staging`
WHERE margin_kgs / NULLIF(revenue_kgs, 0) > 1
ORDER BY margin_pct DESC LIMIT 20;
```
Если это единичные строки с отрицательной себестоимостью → известная проблема (TD-12, COGS на наборах/дуо). Можно временно ослабить порог чека или исключить эти SKU.

**2.5. Currency normalization — тыйыны вместо KGS:**
Признак: значения revenue_kgs > 1 000 000 (ожидаемый максимум на позицию ~500 000 KGS).
```sql
SELECT MAX(revenue_kgs), AVG(revenue_kgs)
FROM `msklad-bi-prod.stg_msklad.fact_sales_staging`;
```
Если max > 10M — деление на 100 не сработало. Проверь `bq_ops.py` → функцию нормализации. Это критический баг — **не промоуть staging в core** до исправления.

---

## 3. Drift по выручке

**Симптом:** DQ Gate упал с `revenue drift > 50%` или алерт мониторинга на аномалию.

### Шаги

**3.1.** Проверь, сколько данных пришло сегодня vs 7-day MA:
```sql
SELECT
  transaction_date,
  SUM(revenue_kgs) AS daily_revenue,
  AVG(SUM(revenue_kgs)) OVER (
    ORDER BY transaction_date
    ROWS BETWEEN 7 PRECEDING AND 1 PRECEDING
  ) AS ma7,
  SUM(revenue_kgs) / NULLIF(AVG(SUM(revenue_kgs)) OVER (
    ORDER BY transaction_date ROWS BETWEEN 7 PRECEDING AND 1 PRECEDING
  ), 0) AS ratio
FROM `msklad-bi-prod.core.fact_sales_profit`
WHERE transaction_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 14 DAY)
GROUP BY 1 ORDER BY 1 DESC;
```

**3.2.** Если ratio < 0.30 — данные не пришли или пришли частично. Причины:
- МойСклад вернул частичный ответ (rate limit timeout)
- Продаж реально не было (праздник, выходной)
- Hourly-окно было пустым (проверь `window_days` в payload)

**3.3.** Если это рабочий день и в МойСкладе продажи есть → принудительный reload:
```bash
curl -s -X POST https://cf-facts-xw5u2boozq-de.a.run.app \
  -H "Authorization: Bearer $(gcloud auth print-identity-token)" \
  -H "Content-Type: application/json" \
  -d '{"mode": "hourly", "force_window_days": 7}' | python3 -m json.tool
```

**3.4.** Если ratio > 3.0 (резкий рост) — проверь не было ли массового ввода задним числом. Нормально если было bulk-import поставок.

---

## 4. Данные не свежие

**Симптом:** Алерт "MAX(transaction_date) старше 6 часов", или заказчик говорит "данные за вчера".

### Шаги

**4.1.** Проверь когда последний раз обновлялась таблица:
```sql
SELECT MAX(transaction_date), MAX(_loaded_at),
  TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), MAX(_loaded_at), HOUR) AS hours_since_load
FROM `msklad-bi-prod.core.fact_sales_profit`;
```

**4.2.** Если `_loaded_at` старше 2 часов → hourly workflow не запускался. Проверь:
```bash
# Последние executions hourly pipeline
gcloud workflows executions list msklad-pipeline-hourly \
  --location=asia-east1 --project=msklad-bi-prod \
  --limit=5 --format="table(name,state,startTime,endTime)"

# Проверить статус Cloud Scheduler job
gcloud scheduler jobs describe msklad-pipeline-hourly-trigger \
  --location=asia-east1 --project=msklad-bi-prod
```

**4.3.** Если Scheduler был PAUSED (или последний статус FAILED):
```bash
# Возобновить scheduler
gcloud scheduler jobs resume msklad-pipeline-hourly-trigger --location=asia-east1

# Или запустить workflow вручную
gcloud workflows run msklad-pipeline-hourly \
  --location=asia-east1 --project=msklad-bi-prod
```

**4.4.** Если `transaction_date` свежий, но `_loaded_at` старый → MERGE отработал, но данных за сегодня в МойСкладе нет (праздник). Нормально.

---

## 5. Дашборд пустой

**Симптом:** Страница Looker Studio показывает "No data" или нули везде.

### Шаги

**5.1.** Проверь источники данных в LS: Edit → каждый Data Source → Refresh fields. Ошибка "Not connected" → проблема с BQ credentials.

**5.2.** Проверь что marts не пустые:
```sql
SELECT 'sales_overview' AS tbl, COUNT(*) FROM `msklad-bi-prod.marts.sales_overview`
UNION ALL SELECT 'inventory_health', COUNT(*) FROM `msklad-bi-prod.marts.inventory_health`
UNION ALL SELECT 'gmroi', COUNT(*) FROM `msklad-bi-prod.marts.gmroi`
UNION ALL SELECT 'abc_xyz', COUNT(*) FROM `msklad-bi-prod.marts.abc_xyz`;
```

**5.3.** Если марты пустые — пересобери вручную:
```bash
cat ~/Desktop/msklad_project/cf/marts/marts_sales_overview.sql \
  | bq query --use_legacy_sql=false --project_id=msklad-bi-prod
```

**5.4.** Если марты не пустые, но LS показывает пусто — проверь фильтры в самом дашборде (Date range filter). Убедись что date range включает данные, которые есть в таблице.

**5.5.** LS Boolean фильтры — **критическое правило (M-11):**
- ✅ Правильно: **Exclude → поле → Equal to → true**
- ❌ Неправильно: Include → поле → Equal to → false
- Применяется к: `is_cogs_missing`, `is_oos`, `is_toxic`

---

## 6. Проблемы с API МойСклад

**Симптом:** В логах CF: `429 Too Many Requests`, `503 Service Unavailable`, или curl возвращает ошибку.

### Диагностика
```bash
# Проверить доступность API (curl ОБЯЗАТЕЛЕН с --compressed, БЕЗ Accept: application/json)
TOKEN=$(gcloud secrets versions access latest --secret=msklad-token --project=msklad-bi-prod)
curl --compressed -s -o /dev/null -w "%{http_code}" \
  "https://api.moysklad.ru/api/remap/1.2/entity/organization" \
  -H "Authorization: Bearer ${TOKEN}"
# Ожидание: 200
```

### Шаги

**6.1.** Если `429` — rate limit. МойСклад: 5 req/sec, 45 одновременных.
- Подожди 5 минут и перезапусти CF.
- Если повторяется — проверь что в коде CF есть `time.sleep(0.21)` между запросами позиций.

**6.2.** Если `503`/`502`/`504` — сервис МойСклада недоступен. Проверь статус:
- https://status.moysklad.ru (или написать в support@moysklad.ru)
- Подожди 15-30 минут, перезапусти.

**6.3.** Если `401 Unauthorized` — токен истёк или неверный:
```bash
# Обновить токен (новый токен взять из МойСклад → Настройки → Токены)
echo -n "NEW_TOKEN_VALUE" | gcloud secrets versions add msklad-token \
  --data-file=- --project=msklad-bi-prod
```

**6.4.** Если `415 Unsupported Media Type` — в curl добавлен `Accept: application/json`. Убрать этот заголовок. Каноническая форма: только `Authorization: Bearer $TOKEN` + `--compressed`.

---

## 7. Workflows упал

**Симптом:** Алерт "msklad-workflow-execution-failed" или "msklad-workflow-silent-skip".

### Шаги

**7.1.** Найди упавший execution и сломанный шаг:
```bash
# Список последних executions
gcloud workflows executions list msklad-pipeline-hourly \
  --location=asia-east1 --project=msklad-bi-prod \
  --limit=5 --format="table(name,state,startTime)"

# Детали последнего упавшего (взять name из предыдущей команды)
gcloud workflows executions describe <EXECUTION_NAME> \
  --workflow=msklad-pipeline-hourly \
  --location=asia-east1 --project=msklad-bi-prod
```

Или в UI: Workflows → Executions → кликни на FAILED execution → вкладка Graph.

**7.2.** В деталях execution найди имя упавшего шага. Маппинг:

| Шаг в workflow | Что делает | Куда смотреть |
|---|---|---|
| `step_dim` | CF-Dim запуск | Логи cf-dim |
| `step_fx` | CF-FX (курсы НБКР) | [13. FX-курсы](#13-fx-курсы-отсутствуют-нбкр) |
| `step_facts` | CF-Facts hourly/weekly | Логи cf-facts |
| `step_dq` | CF-DQ качество данных | [2. DQ Gate](#2-dq-gate-провалился) |
| `parse_dq_result` | Разбор ответа DQ | Проверь формат ответа CF-DQ |
| `check_dq` | Принятие решения по DQ | Проверь `dq_parsed.passed` |
| `step_promote` | Промоут staging → core | Логи cf-facts (mode=promote) |
| `step_purchases` | CF-Facts purchases | Логи cf-facts (mode=purchases) |
| `step_returns` | CF-Facts returns | Логи cf-facts (mode=returns) |

**7.3.** Открой логи конкретной CF из таблицы выше → следуй в соответствующий раздел Runbook.

**7.4.** Если ошибка разовая (не воспроизводится) → запусти workflow вручную:
```bash
gcloud workflows run msklad-pipeline-hourly \
  --location=asia-east1 --project=msklad-bi-prod \
  --data='{"reason": "manual_retry"}'
```

**7.5. Silent skip (алерт "нет executions 2 часа"):**
```bash
# Проверить что Scheduler работает
gcloud scheduler jobs describe msklad-pipeline-hourly-trigger \
  --location=asia-east1 --project=msklad-bi-prod

# Проверить что не PAUSED и не FAILED
gcloud scheduler jobs list --location=asia-east1 --project=msklad-bi-prod

# Если PAUSED — возобновить
gcloud scheduler jobs resume msklad-pipeline-hourly-trigger --location=asia-east1

# Если FAILED — посмотреть причину и перезапустить
gcloud scheduler jobs run msklad-pipeline-hourly-trigger --location=asia-east1
```

**7.6.** Перед перезапуском workflow проверь, не застрял ли staging:
```sql
SELECT COUNT(*), MAX(_loaded_at) FROM `msklad-bi-prod.stg_msklad.fact_sales_staging`
WHERE DATE(_loaded_at) = CURRENT_DATE();
```
Если строки есть, но promote не прошёл — TRUNCATE staging и перезапускай (rolling MERGE идемпотентен).

---

## 8. Дрейф исторических данных

**Симптом:** Заказчик: "Маржа за прошлый месяц вчера была одна, сегодня другая".

Это **нормальное поведение**: `report/profitability/bygood` МойСклада пересчитывает FIFO при новых поставках.

### Шаги

**8.1.** Объясни заказчику — ответ на виджете маржи в LS: *"Данные за последние 90 дней уточняются еженедельно при пересчёте себестоимости"*.

**8.2.** Если расхождение > 10% за месяц — проверь не было ли массового ввода поставок задним числом:
```sql
SELECT supply_date, COUNT(*), SUM(sum_kgs) AS supply_sum
FROM `msklad-bi-prod.core.fact_purchases`
WHERE _loaded_at > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 24 HOUR)
GROUP BY supply_date ORDER BY supply_date DESC LIMIT 30;
```

**8.3.** Принудительный rolling reload 90 дней:
```bash
curl -s -X POST https://cf-facts-xw5u2boozq-de.a.run.app \
  -H "Authorization: Bearer $(gcloud auth print-identity-token)" \
  -H "Content-Type: application/json" \
  -d '{"mode": "weekly", "window_days": 90}' | python3 -m json.tool
```

---

## 9. UUID кастомного поля изменился

**Симптом:** "В пути" = 0, хотя заказы есть. Или `country` = NULL у всех контрагентов.

### Шаги

**9.1.** Проверь актуальные UUID в МойСклад UI → Настройки → Кастомные поля → скопируй ID нужного поля.

**9.2.** Сравни с тем что в таблице:
```sql
SELECT * FROM `msklad-bi-prod.core.dim_metadata_mappings`;
```

**9.3.** Если UUID изменился:
```sql
UPDATE `msklad-bi-prod.core.dim_metadata_mappings`
SET current_uuid = 'NEW_UUID_HERE',
    last_verified = CURRENT_TIMESTAMP()
WHERE field_name = 'shelf_life';  -- или 'in_transit_status', 'country'
```

**9.4.** Перезапусти CF-Dim вручную → проверь что поле заполнилось.

**9.5.** Запиши в [Журнал](#журнал-инцидентов) с пометкой когда и какой UUID менялся.

---

## 10. Изменение менеджера контрагентов

**Симптом:** "Айгуль уволилась, её клиентов переводим на Бакыта".

Точечный SCD2 на `dim_counterparties.owner_employee` отработает автоматически. Проверь.

### Шаги

**10.1.** Дождись следующего запуска CF-Dim (раз в сутки) или запусти вручную.

**10.2.** Проверь что SCD2 отработал:
```sql
SELECT agent_id, owner_employee, valid_from, valid_to, scd2_is_current
FROM `msklad-bi-prod.core.dim_counterparties`
WHERE agent_id IN (
  SELECT DISTINCT agent_id FROM `msklad-bi-prod.core.dim_counterparties`
  WHERE owner_employee IN ('Айгуль', 'Бакыт')
)
ORDER BY agent_id, valid_from;
```

Должно быть две записи на каждый изменившийся агент:
- `scd2_is_current=false`, `valid_to=<вчера>`, `owner_employee='Айгуль'`
- `scd2_is_current=true`, `valid_to=NULL`, `owner_employee='Бакыт'`

**10.3.** Выручка за прошлые периоды должна остаться у Айгуль, новые продажи — у Бакыта. Если выручка "переехала" — SCD2 сломан. Эскалация.

---

## 11. Полная пересборка core из raw

**Когда:** Core повреждён, нужно пересобрать из сырых JSON в GCS.

### Шаги

**11.1.** Backup текущего core:
```sql
CREATE TABLE `msklad-bi-prod._backup.fact_sales_profit_YYYYMMDD`
CLONE `msklad-bi-prod.core.fact_sales_profit`;
```

**11.2.** Очистить core:
```sql
TRUNCATE TABLE `msklad-bi-prod.core.fact_sales_profit`;
```

**11.3.** Запустить пересборку из GCS:
```bash
python scripts/rebuild_core_from_raw.py \
  --start-date 2025-01-01 \
  --end-date $(date +%Y-%m-%d) \
  --table fact_sales_profit \
  --project msklad-bi-prod
```

**11.4.** Сверить суммы до/после:
```sql
SELECT SUM(revenue_kgs) AS new_total, COUNT(*) AS new_rows
FROM `msklad-bi-prod.core.fact_sales_profit`;
-- Сравни с backup таблицей
```
Расхождение > 1% → эскалация.

---

## 12. Откат через BigQuery time travel

**Когда:** Неудачный MERGE/UPDATE сломал core. Доступно в течение 7 дней.

### Шаги

**12.1.** Определи timestamp нормального состояния (сколько часов назад всё было хорошо).

**12.2.** Создай таблицу из снимка прошлого:
```sql
CREATE OR REPLACE TABLE `msklad-bi-prod.core.fact_sales_profit_restored` AS
SELECT *
FROM `msklad-bi-prod.core.fact_sales_profit`
FOR SYSTEM_TIME AS OF TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 6 HOUR);
-- Поменяй INTERVAL на нужный. Максимум — 7 дней.
```

**12.3.** Сверь данные в `_restored` — это то, к чему откатываемся.

**12.4.** Замени основную таблицу:
```sql
DROP TABLE `msklad-bi-prod.core.fact_sales_profit`;
ALTER TABLE `msklad-bi-prod.core.fact_sales_profit_restored`
  RENAME TO fact_sales_profit;
```

**12.5.** Перезапусти marts Scheduled Queries вручную — иначе LS покажет старые цифры:
```bash
# Форсировать пересборку всех мартов
for sql_file in ~/Desktop/msklad_project/cf/marts/marts_*.sql; do
  echo "Пересобираю $(basename $sql_file)..."
  cat "$sql_file" | bq query --use_legacy_sql=false --project_id=msklad-bi-prod
done
```

---

## 13. FX-курсы отсутствуют (НБКР)

**Симптом:** CF-Dim упал с ошибкой "dim_fx_rates устарела: N дней назад". Или lag > 3 дня в логах cf-fx. Или алерт от мониторинга на FX freshness.

**Контекст (инцидент М-08):** НБКР не публикует курсы в выходные дни и праздники. Lag суббота→понедельник = 3 дня, длинные выходные = 4-5 дней. CF-Dim использует tolerance 5 дней (пропатчено в revision 00012-waj). CF-FX возвращает `rows_added: 0` при отсутствии публикации — это норма, не баг.

### Диагностика

```sql
-- Проверить последнюю дату курса
SELECT MAX(date) AS last_fx_date,
  DATE_DIFF(CURRENT_DATE(), MAX(date), DAY) AS lag_days
FROM `msklad-bi-prod.core.dim_fx_rates`;
```

### Шаги

**13.1.** Если `lag_days <= 5` — ещё в пределах tolerance CF-Dim. Дождись когда НБКР опубликует курс (обычно в первый рабочий день после выходных).

**13.2.** Если `lag_days > 5` или CF-Dim уже упал → нужен forward-fill:

```sql
-- Forward-fill: заполнить недостающие даты последним известным курсом
INSERT INTO `msklad-bi-prod.core.dim_fx_rates` (date, rate_kgs_per_usd)
SELECT d AS date,
  (SELECT rate_kgs_per_usd FROM `msklad-bi-prod.core.dim_fx_rates`
   ORDER BY date DESC LIMIT 1) AS rate_kgs_per_usd
FROM UNNEST(GENERATE_DATE_ARRAY(
  DATE_ADD((SELECT MAX(date) FROM `msklad-bi-prod.core.dim_fx_rates`), INTERVAL 1 DAY),
  CURRENT_DATE()
)) AS d
WHERE d NOT IN (SELECT date FROM `msklad-bi-prod.core.dim_fx_rates`);
```

**13.3.** Верифицировать:
```sql
SELECT MAX(date), COUNT(*) AS new_rows
FROM `msklad-bi-prod.core.dim_fx_rates`
ORDER BY date DESC LIMIT 5;
```

**13.4.** После forward-fill — запусти CF-Dim вручную (если он упал из-за FX):
```bash
curl -s -X POST https://cf-dim-xw5u2boozq-de.a.run.app \
  -H "Authorization: Bearer $(gcloud auth print-identity-token)" \
  -H "Content-Type: application/json" \
  -d '{"mode": "full"}' | python3 -m json.tool
```

**13.5.** Запиши в журнал когда был gap и за какой период форвард-филлили.

⚠️ **Внимание:** forward-fill берёт последний известный курс. Если курс за выходные реально изменился (что редко), после публикации НБКР нужно будет удалить forward-fill строки и заново запустить CF-FX:
```sql
-- Удалить forward-fill строки (только если НБКР потом опубликовал реальные данные)
-- СНАЧАЛА проверь что CF-FX добавил реальные строки, потом удаляй дубли
DELETE FROM `msklad-bi-prod.core.dim_fx_rates`
WHERE date IN (SELECT date FROM `msklad-bi-prod.core.dim_fx_rates` GROUP BY date HAVING COUNT(*) > 1);
```

---

## Эскалация

Если ничего из Runbook не помогло:

1. Собери диагностический пакет:
   - Текст ошибки (полный, с traceback)
   - Timestamp инцидента (UTC)
   - Имя упавшего workflow шага / CF
   - `gcloud logging read` последние 50 строк
   - Что уже попробовал из Runbook

2. Контакты:
   - **Ilyas Bazarov** (owner): Telegram @ilyasbazarov
   - **support@moysklad.ru**: Техподдержка МойСклада
   - **GCP Support**: https://cloud.google.com/support

3. **Правило:** не делай ничего деструктивного без второй пары глаз при уверенности < 100%. Лучше дашборд полежит ещё час, чем потеряешь данные.

---

## Приложение A: IAM checklist — роли etl-sa

Если что-то перестало работать после изменений в IAM → проверить что у `etl-sa@msklad-bi-prod.iam.gserviceaccount.com` есть все нужные роли.

```bash
# Посмотреть текущие роли
gcloud projects get-iam-policy msklad-bi-prod \
  --flatten="bindings[].members" \
  --format="table(bindings.role)" \
  --filter="bindings.members:etl-sa@msklad-bi-prod.iam.gserviceaccount.com"
```

| Роль | Зачем |
|---|---|
| `roles/bigquery.dataEditor` | Запись в BQ datasets (core, stg_msklad, marts, audit) |
| `roles/bigquery.jobUser` | Запуск BQ jobs (MERGE, INSERT, CREATE TABLE) |
| `roles/storage.objectCreator` | Запись в GCS msklad-raw |
| `roles/storage.objectViewer` | Чтение из GCS |
| `roles/secretmanager.secretAccessor` | Чтение MSKLAD_TOKEN из Secret Manager |
| `roles/workflows.invoker` | Запуск Workflows (если CF вызывает Workflow напрямую) |
| `roles/run.invoker` | Вызов других Cloud Run сервисов |
| `roles/logging.logWriter` | Запись логов (Cloud Functions автоматически) |
| `roles/cloudscheduler.jobRunner` | (для Scheduler SA, не etl-sa) |

Восстановить недостающую роль:
```bash
gcloud projects add-iam-policy-binding msklad-bi-prod \
  --member="serviceAccount:etl-sa@msklad-bi-prod.iam.gserviceaccount.com" \
  --role="roles/bigquery.dataEditor"
```

---

## Приложение B: Периодические проверки (раз в неделю)

Пробежать в понедельник утром (~10 минут):

- [ ] Все Workflow за прошлую неделю — зелёные?
  ```bash
  gcloud workflows executions list msklad-pipeline-hourly --location=asia-east1 \
    --filter="state=FAILED OR state=CANCELLED" --limit=10
  ```
- [ ] Свежесть: `MAX(transaction_date)` не старше 2 часов?
- [ ] DQ Gate за неделю не падал ни разу?
- [ ] FX-курсы обновлялись каждый день? (`SELECT MAX(date) FROM dim_fx_rates;`)
- [ ] Audit-snapshots dim'ов делаются ежедневно?
- [ ] Telegram-алерты доходят? (раз в месяц тестовый алерт)
- [ ] Backup'ы создаются? (`SELECT * FROM _backup.INFORMATION_SCHEMA.TABLES ORDER BY creation_time DESC LIMIT 5`)
- [ ] BQ траты в пределах ожидаемого? (Console → Billing → Reports)
- [ ] Марты не пустые и обновлялись сегодня? (см. раздел 5 Runbook)

---

## Журнал инцидентов

| Дата | Симптом | Раздел | Что сделал | Что помогло | Время до фикса |
|---|---|---|---|---|---|
| 2026-05-11 | mode=returns отсутствовал в main.py | §1.8 | Реализован полный mode=returns, задеплоен revision 3 | Реализация + деплой | 2ч |
| 2026-05-11 | fact_returns: 62 строки → 10 после smoke-test | §1 (custom) | Перезапуск с window_days=730 | window_days=730 восстановил 62 строки | 15 мин |
| 2026-05-11 | marts.gmroi no_inventory=100% | §9 аналог | BQ UPDATE 1448 строк + патч _parse_href в cf-inventory | split("?")[0] в parse_href | 1ч |
| 2026-05-12 | product_folder=NULL у всех 4463 товаров | §9 аналог | _fetch_folder_map() в cf-dim, revision 00013-boq | Отдельный запрос к productfolder API | 2ч |
| 2026-05-13 | FX lag > 3 дня (выходные) | §13 | forward-fill 4 строки + tolerance 5d в cf-dim | INSERT forward-fill + revision 00012-waj | 20 мин |
| 2026-05-13 | discount_percent в marts.sales_overview = NULL | §5 аналог | sed-патч f.discount_percent → f.discount AS discount_percent | Пересборка марта | 10 мин |

---

**Версия 2.0** | Обновлён: 2026-05-15  
_Документ — живой. Каждый новый инцидент = новая запись в Журнале._
