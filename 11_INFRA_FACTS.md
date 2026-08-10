# 11 · INFRA_FACTS — волатильные инфра-факты

**Версия:** 0.3 (+ §CF/§секреты cf-alert, `INFRA-FACTS-LANDING`) · **Статус:** LIVING
**Назначение:** канонический реестр волатильных инфра-фактов — URL/ревизии CF, Config ID SQ, расписания, IAM, секреты (имена). Обновляется часто, при каждом деплою/ротации секретов (ADR-004).
**Состав по `00_CHARTER §карта документов` стр.53.**

---

## §CF (URL/ревизии)

**cf-finance** (конфигурация актуальна на 2026-06-25, PR-13):
```bash
gcloud functions deploy cf-finance \
  --gen2 --runtime=python312 --region=asia-east1 \
  --source=. --entry-point=main \
  --trigger-http \
  --service-account=etl-sa@msklad-bi-prod.iam.gserviceaccount.com \
  --memory=512MB --timeout=1800s \
  --set-secrets="MSKLAD_TOKEN=msklad-token:latest"
```
- Исходники: `/home/ilyasbazarov4/cf-finance` (Cloud Shell persistent disk)
- Revision: **`cf-finance-00012-cik`**, `updateTime = 2026-07-20T15:21:20Z` (факт, сессия E1-T1-MECH-PREP 2026-07-26, `Q-44` ЗАКРЫТ). История: `00001-wiv` первый деплой 2026-06-18 → `00005-wob` фикс таймаута 2026-06-25 → `00006-piv` фикс `trigger_marts()` 2026-06-25 → … → `00012-cik`. Промежуточные `00007…00011` не восстановлены (DEFER, археология). **Currency-fix `ADR-016` в этой ревизии ЕСТЬ** (`Q-45` ЗАКРЫТ, ДА): умножение на `rate.value` в `main.py` стр.66–68; sha256 текущего `main.py` = `0cb4f6698a61cee96c90f9a14973ada38f5123418b54ff901f24ea2026ddab59`; в архиве лежит до-фиксовый `main.py.pre-e1t3-mech-fx.bak`, sha256 `7a5d8dcd7866a887eb940accab709487eb27cba42a3446478b83678c67fa181d`. Задеплоенный архив не чист (`Q-57`) — очистка вменена следующему деплою как условие, `ADR-040`.
- URI (Cloud Run native): `https://cf-finance-xw5u2boozq-de.a.run.app`
- Legacy URL: `https://asia-east1-msklad-bi-prod.cloudfunctions.net/cf-finance`
- Cloud Scheduler: `finance-daily-update`, регион **`asia-east1`**, `0 3 * * *`, `Asia/Bishkek` (⇒ срабатывание 21:00 UTC предыдущих суток), HTTP POST на URI выше. **`attemptDeadline=1800s`** — поднят с `180s` 2026-07-26 по `ADR-023 §5/§6` (Scheduler-side `jobs update`, не редеплой; read-back подтверждён, провенанс `/reference/sched_attempt_deadline_readback_2026-07-26.md`). Серверный `--timeout` самой CF = `1800s` ⇒ значения совпадают, ложный клиентский 504 исключён by construction (`ADR-023 §5`); `Q-43` CLOSED. Полный `retryConfig`: `maxRetryDuration=0s` (ретраев НЕТ — DROP-DUP c RB-42; падение Scheduler тихо проглатывается, алерт только от мониторинга 5xx на Cloud Run), `minBackoffDuration=5s`, `maxBackoffDuration=3600s`, `maxDoublings=5`. Вызов аутентифицирован через `--oidc-service-account-email=etl-sa@msklad-bi-prod.iam.gserviceaccount.com` (`ADR-022`, с 2026-07-20; сохранён при partial-update 2026-07-26). `state: ENABLED`.
- Cloud Scheduler: `loss-commission-daily-update`, регион **`asia-east1`**, `0 3 * * *`, `Asia/Bishkek`, HTTP POST, тело вызова `{}` ⇒ загрузчик берёт окно `2020-01-01 → завтра`, то есть всю историю (`/reference/code/cf-loss-commission/main.py` стр.241–243). `attemptDeadline=1800s` — заведён так изначально (`ADR-031 §6`), **подтверждён read-back'ом 2026-07-26**; до этого был заявкой в тексте ADR, не фактом (`ADR-021 §2`). `retryConfig`: `maxRetryDuration=0s`, `minBackoffDuration=5s`, `maxBackoffDuration=3600s`, `maxDoublings=5`. OIDC `etl-sa@msklad-bi-prod.iam.gserviceaccount.com`. `state: ENABLED`. **Пересборку марта НЕ триггерит** — в коде нет ни `transferConfig`, ни `StartManualTransferRuns` (в отличие от `cf-finance.trigger_marts()`, `ADR-038`) ⇒ ручной прогон безопасен для живой витрины. Запись идемпотентна: стейджинг `WRITE_TRUNCATE` → `MERGE` с явными колонками (`ADR-030`/C1).
- **Инвентарь Cloud Scheduler (факт, E1-T1-MECH-PREP-ADJ, `2026-07-25T19:44:52Z` по `date -u`):** регион всех джобов — `asia-east1`; всего пять, все `state: ENABLED`. `msklad-pipeline-hourly` (`0 * * * *`) · `cf-inventory-trigger` (`0 21 * * *`) · `finance-daily-update` (`0 3 * * *`, `Asia/Bishkek`) · `loss-commission-daily-update` (`0 3 * * *`, `Asia/Bishkek`) · `msklad-pipeline-weekly` (`0 1 * * 0`). До этой сессии в `11 §CF` был документирован только `finance-daily-update`. Смежное: состав шагов `msklad-pipeline-weekly` — см. `01_ARCHITECTURE.md §DAG` (факт 2026-08-07); `cf-inventory-trigger` в репо ранее не упоминался вовсе.
- ⚠️ TD-SEC-01 — подтверждённый инцидент 2026-07-20, устранён IAM-lockdown (ADR-022): `allUsers`-invoker снят, вызов только через `etl-sa` (OIDC).
- Ops-следствие (ADR-022 §4, флаг, не гейт): после lockdown любой ручной/ad-hoc вызов `cf-finance` требует identity-token, анонимный `curl` больше не работает. `10_OPS_PLAYBOOK` не существует (Q-35, DEFER) — нота живёт здесь.

**cf-fx** (после миграции 2026-06-03, PR-18):
- Внешний источник (не собственный CF URL, а вызываемый API): `BAKAI_FX_URL = "https://openbanking-api.bakai.kg/api/Directory/GetRateDirectory"` (Bakai Bank OpenBanking API → `officialRates[USD].rate`, курс НБКР).
- Ревизия/URL самой CF `cf-fx`: не зафиксированы в источнике на момент этой сессии → *(пусто, ожидает discovery)*.

**cf-facts** (снято сессией `SOURCE-MAP-SALES`, 2026-07-29/30; полная таблица метаданных и метод снятия —
`reference/code/cf-facts/MANIFEST.md`):
```bash
gcloud functions deploy cf-facts \
  --gen2 --runtime=python312 --region=asia-east1 \
  --source=cf/cf_facts --entry-point=main \
  --service-account=etl-sa@msklad-bi-prod.iam.gserviceaccount.com \
  --memory=2048MB --timeout=540s --min-instances=1 \
  --set-secrets="MSKLAD_TOKEN=msklad-token:latest"
```
(команда деплоя — из докстринга `main.py:20-26` в снапшоте, не наблюдённый факт живого деплоя)
- Регион: **`asia-east1`**. Revision: **`cf-facts-00007-xir`**, `updateTime = 2026-07-29T04:05:10.487996910Z`,
  `createTime = 2026-05-06T08:26:29.388991725Z`, `state: ACTIVE`.
- Источник: `gs://gcf-v2-sources-420804682491-asia-east1/cf-facts/function-source.zip`, `generation
  1782334223015697`. Архив грязный (`.bak`/patch-скрипты/`.DS_Store`/вложенный устаревший `src.zip`) —
  чистка вменена следующему деплою (`ADR-040`), см. `MANIFEST.md §Чистота архива`.
- URI (Cloud Run native): `https://cf-facts-xw5u2boozq-de.a.run.app`
- Legacy URL: `https://asia-east1-msklad-bi-prod.cloudfunctions.net/cf-facts`
- `serviceAccountEmail`: `etl-sa@msklad-bi-prod.iam.gserviceaccount.com`. `timeoutSeconds: 540`.
  `availableMemory: 2048M`, `availableCpu: 1`. `minInstanceCount: 1`, `maxInstanceCount: 5`.
  `ingressSettings: ALLOW_ALL`.
- Секреты (имена, не значения): `MSKLAD_TOKEN` ← `msklad-token:latest`.
- Триггер: **`HTTP_TRIGGER`** (прямой HTTP, не Pub/Sub/Eventarc). Вызывающий Cloud Scheduler job не
  идентифицирован этой сессией (не входил в шаги брифа буквально; `workflow.yaml`, оркестрирующий режимы
  `hourly`/`weekly`/`promote`/`purchases`/`returns`, вне архива — остаток, не факт).
- **Известная аномалия этой сессии (не факт о самой CF):** `gcloud functions describe cf-facts` вернул
  `403`/billing-related ошибку трижды подряд, при том что `gcloud functions list` тем же аккаунтом отработал.
  Прямая проверка `gcloud billing projects describe msklad-bi-prod` подтвердила `billingEnabled: false`;
  владелец восстановил биллинг в ходе сессии (подтверждено повторной проверкой: `billingEnabled: true`).
  Метаданные выше сняты эквивалентным путём (`functions list --format=json` + `run services describe`) до
  восстановления и не переверены `describe` после. Провенанс — `reference/code/cf-facts/MANIFEST.md
  §Известная аномалия сессии`, логи `reference/_scratch_SOURCE-MAP-SALES_2026-07-29/step1*.log`.
- **Пересборку марта НЕ триггерит** — `grep -rn "trigger_marts" reference/code/cf-facts/` даёт 0 совпадений
  (в отличие от `cf-finance.trigger_marts()`, `ADR-038`). `marts.sales_overview` обновляется исключительно
  по собственному расписанию SQ, независимо от момента промоута в `core`.
- MERGE в `core.fact_sales_profit` — явный `INSERT (колонки) VALUES (...)`, не `INSERT ROW`
  (`bq_ops.py:258-303`) — соответствует C1/`ADR-030`.
**cf-dq** (факт, замер сессии `FACTS-WORKFLOW-STOP-DIAG`, `2026-08-02`, скрипт
`reference/_scratch_FACTS-WORKFLOW-STOP-DIAG_2026-08-02/step3_cf_revisions.sh`, лог `step3_run.log`;
`gcloud functions describe cf-dq --region=asia-east1 --gen2` отработал без `403`):
- Регион: `asia-east1`. `createTime` функции — `2026-05-07T12:53:10.388923634Z`.
- Revision: **`cf-dq-00007-hot`**, создана `2026-06-18T10:59:31.089576Z`, `state: ACTIVE`;
  `latestReadyRevisionName` совпадает. `updateTime` сервиса — `2026-07-30T10:04:58.501779835Z`
  (метаданная-правка массовой сессии того дня, не передеплой кода).
- История ревизий (полная, `gcloud run revisions list --service=cf-dq`): `00007-hot`
  `2026-06-18`, `00006-lac` `2026-05-26`, `00005-pet` и `00004-teh` `2026-05-18`, `00003-reh`,
  `00002-gov`, `00001-wiz` `2026-05-07`.
- ⚠ **Расхождение с прозой доков, не закрытое этим фактом.** Прежняя редакция этой строки и
  `03_PIPELINE_SPEC.md:88` говорят о «ревизии после T-1-фикса», датируя фикс `2026-06-24`. Ни одна
  ревизия `cf-dq` этой датой не создана; ровно ей датирована ревизия ДРУГОЙ функции —
  `cf-facts-00007-xir`, `2026-06-24T20:52:00.773262Z` (тот же лог). Наблюдаемое поведение гейта
  стандарту T-1 соответствует (`target_date` = вчерашние бишкекские сутки). Разбор — при чтении
  кода, задача `DQ-SOURCE-CAPTURE`; адъюдикация — `reference/facts_stop_diag_adj_2026-08-02.md §6`.
- **Исходный код `cf-dq` в `reference/code/` НЕ снят** — остаток `Q-3`, закрывается
  `DQ-SOURCE-CAPTURE`. Ревизия (прежний `GAP Q-6`) снята и закрыта этим фактом.

**cf-inventory** (факт, сессия `SOURCE-MAP-REST`, `2026-07-30T10:47:33Z`…`10:47:49Z`, `MANIFEST.md` — `reference/code/cf-inventory/MANIFEST.md`):
- Регион: `asia-east1` (`gcloud functions list --filter="name:cf-inventory"`).
- Revision: **`cf-inventory-00003-vuf`**, `createTime = 2026-05-07T09:09:33.031784952Z`, `updateTime = 2026-07-30T10:04:58.467601786Z`, `state: ACTIVE`.
- `entryPoint`: `main`. `source.storageSource`: `gs://gcf-v2-sources-420804682491-asia-east1/cf-inventory/function-source.zip` (generation `1778486115150159`).
- URI (Cloud Run native): `https://cf-inventory-xw5u2boozq-de.a.run.app`. Legacy URL: `https://asia-east1-msklad-bi-prod.cloudfunctions.net/cf-inventory`.
- `serviceAccountEmail`: `etl-sa@msklad-bi-prod.iam.gserviceaccount.com`. `timeoutSeconds`: `540`. `availableMemory`: `512M`. `availableCpu`: `0.3333`. `maxInstanceCount`: `3`. `ingressSettings`: `ALLOW_ALL`.
- `secretEnvironmentVariables`: `MSKLAD_TOKEN` ← секрет `msklad-token`, версия `latest`.
- Триггер — HTTP (нет `eventTrigger` в описании). Cloud Scheduler `cf-inventory-trigger`, регион `asia-east1`, `schedule: 0 21 * * *`, `timeZone: UTC` (⇒ 03:00 KGT), `state: ENABLED`. `attemptDeadline: 180s` — **меньше** серверного `timeoutSeconds` (540s), тот же класс риска, что `ADR-023` устраняла у `finance-daily-update` (флаг, не фикс — фикс-форвард не производится этой сессией). OIDC `serviceAccountEmail: etl-sa@msklad-bi-prod.iam.gserviceaccount.com`. `retryConfig`: `maxRetryDuration=0s`, `minBackoffDuration=5s`, `maxBackoffDuration=3600s`, `maxDoublings=5`.
- Ранее в этом файле джоба `cf-inventory-trigger` упоминалась только строкой 27 (имя+расписание, инвентарь всех джобов, `E1-T1-MECH-PREP-ADJ`) — эта запись дополняет `attemptDeadline`/OIDC/retryConfig фактом.

Источник-адрес: `00_CHARTER §карта документов` стр.53; ADR-004 §Последствия (PR-13); PR-35 правило 41 (DROP-DUP); RB-42 (`maxRetryDuration=0s`); `cf-inventory` — `SOURCE-MAP-REST` (`ADR-079 §7b`).

**cf-alert** (факт **2026-08-01**, `gcloud functions describe cf-alert --project=msklad-bi-prod --region=asia-east1 --gen2`, `reference/infra_facts_sweep_2026-08-01.md §Q-12`, сырой лог `reference/_scratch_INFRA-FACTS-SWEEP_2026-08-01/step1_gcloud_describe.log:97-147`):
- Регион: `asia-east1`. Revision: **`cf-alert-00001-bej`** — единственная с момента создания, ни разу не редеплоена. `createTime`: `2026-05-13T12:23:18.665754631Z`. `updateTime`: `2026-07-30T10:04:58.439199216Z` (та же дата стоит у `cf-dq`/`cf-inventory`/`msklad-pipeline-weekly` — метаданная-правка массовой сессии того дня, не передеплой кода, см. строки 77–78 выше). `state: ACTIVE`.
- URI (Cloud Run native): `https://cf-alert-xw5u2boozq-de.a.run.app`. Legacy URL: `https://asia-east1-msklad-bi-prod.cloudfunctions.net/cf-alert`.
- `serviceAccountEmail`: `etl-sa@msklad-bi-prod.iam.gserviceaccount.com`. `timeoutSeconds`: `30`.
- `secretEnvironmentVariables`: `TELEGRAM_BOT_TOKEN` ← секрет `telegram-bot-token`, версия `latest`; `TELEGRAM_CHAT_ID` ← секрет `telegram-chat-id`, версия `latest` (имена — не значения; полный состав секретов проекта — §секреты (имена) ниже).
- Триггер — HTTP. Роль в схеме уведомления (факт **2026-08-02**, `reference/dq_source_capture_2026-08-02.md §5`): webhook-канал Cloud Monitoring для Telegram; ни `cf-dq`, ни тексты обоих Cloud Workflow (`msklad-pipeline-hourly`/`-weekly`) его не вызывают (сплошной `grep`, 0 совпадений в обоих) — политики оповещения Cloud Monitoring используют два канала, email плюс webhook на `cf-alert`.
- Исходный код `cf-alert` в `reference/code/` НЕ снят — остаток `Q-3`, отдельная задача.
- Текущее состояние фильтра лог-метрики DQ-алерта (`msklad_dq_gate_failed`) — закрыто отдельной задачей `DQ-ALERT-FILTER-FIX` (`ADR-149`, `reference/dq_alert_filter_fix_2026-08-09.md`), здесь не пересказывается.

## §SQ (Config ID + расписания)

Источник: `reference/sql/README.md` (выгрузка 2026-07-07, проект `msklad-bi-prod`, location `asia-east1`) · ADR-008 §Решение (1) · PR-21.

| Config ID | displayName | Целевая таблица | Schedule | Состояние |
|---|---|---|---|---|
| `69fc93d1-0000-2d64-bdd1-30fd381336b4` | `sq_audit_dim_products_snapshot` | `msklad-bi-prod.audit.dim_products_snapshots` | every day 04:00 (подтверждено run history 2026-07-17: 71 прогон, все 04:00 UTC) | ⚠ **FAILED с 2026-06-03** — schema drift (ADR-019): `Inserted row has wrong column count; Has 15, expected 14 at [2:1]`. Дельта = `weight` FLOAT64 (`core.dim_products` поз.14, в цели отсутствует); поз.1–13 идентичны; `snapshot_at` занимает поз.14 цели ⇒ `ALTER … ADD COLUMN` НЕ чинит (ADR-019 §3). Последний срез 2026-06-02 04:00:10; дыра 45 суток безвозвратна. Фикс = вариант E → задача `AUDIT-SNAPSHOT-FIX` (после Step 6 `E1-T3-MECH-FX`). Пометка «as-is, не чинить» СНЯТА (ADR-019). Провенанс: `/reference/sq_audit_dim_products_drift_2026-07-17.md` |
| `69fc9c75-0000-2ab4-91b3-883d24f4db64` | `sq_audit_dim_counterparties_snapshot` | `msklad-bi-prod.audit.dim_counterparties_snapshots` | every day 04:00 | SUCCEEDED |
| `69fc9d6e-0000-2ab4-91b3-883d24f4db64` | `sq_audit_dim_employees_snapshot` | `msklad-bi-prod.audit.dim_employees_snapshots` | every day 04:00 | SUCCEEDED |
| `6a22a243-0000-20fd-a458-883d24f4cad4` | `sq_marts_expenses` | `msklad-bi-prod.marts.expenses` | **ежедневно, якорь 11:10 UTC (факт: прогоны 25/26/27.07.2026, ровно один в сутки).** Поля `schedule` в выдаче НЕТ (не пусто); расписание в `scheduleOptionsV2 = {'timeBasedSchedule': {}}` ⇒ суточный интервал по умолчанию, якорь совпадает с `updateTime 2026-06-05T11:10:23Z`. `nextRunTime` активен | SUCCEEDED · провенанс: `/reference/sq_cadence_2026-07-27.md §3/§4` (`ADR-045 §6`), артефакт в репо @ `9465294` · **запрос заменён cutover'ом 2026-07-27T15:52Z** (union `fact_payments`+`fact_loss`+`fact_commissionreportin`); снимок — `/reference/sql/sq_marts_expenses.sql` @ `9465294`, 3114 байт, оба новых источника присутствуют; доcutover-версия — `/reference/sql/sq_marts_expenses_pre_e1t1_2026-07-27.sql`, 1359 байт · **каденция одноканальная:** замер `INFORMATION_SCHEMA.JOBS_BY_PROJECT` за 13–28.07 (`/reference/bq_jobs_2026-07-28.md §3/§4`) даёт ровно один прогон в сутки в 11:10 UTC, пятнадцать суток без исключений; второй путь `ADR-038` (`cf-finance.trigger_marts()`) не проявился ни разу при подтверждённой видимости ручных прогонов в том же инструменте; ручной прогон `2026-07-27T15:53:48Z` — подтверждение cutover (`ADR-073 §4/§5/§8`) |
| `6a23f3ea-0000-2952-853d-582429be7ecc` | `sq_marts_customer_invoices_ar` | `msklad-bi-prod.marts.customer_invoices_ar` | **ежедневно, якорь 10:00 UTC.** Поля `schedule` в выдаче НЕТ (не пусто); `scheduleOptions {}`, расписание в `scheduleOptionsV2`; `nextRunTime 2026-07-28T10:00:00Z`, `updateTime 2026-06-05T10:00:27Z`. Остаток Q-21 ЗАКРЫТ | SUCCEEDED · 0 не-OK / 43 · провенанс: `/reference/sq_fleet_health_2026-07-17.md` (ADR-020 §6) |
| `69ff34b4-0000-2b2b-a390-14c14ef7af10` | `sq_marts_sales_overview` | `msklad-bi-prod.marts.sales_overview` | **`every 2 hours`** (явное расписание в конфиге; nextRunTime 2026-07-27T15:34:00Z) | SUCCEEDED · провенанс: `/reference/sq_cadence_2026-07-27.md §4`, артефакт в репо @ `9465294`; двухчасовая каденция подтверждена конфигом и замером 319 заданий (`/reference/bq_jobs_2026-07-28.md §3`), наблюдение `Q-64` снято (`ADR-073 §4`) |
| `6a0aa537-0000-260f-b391-d43a2cee6b87` | `sq_marts_in_transit` | `msklad-bi-prod.marts.in_transit` | `every 24 hours`, якорь `~13:09 UTC` (подтверждено прогонами `2026-07-27T13:09:03Z`, `2026-07-28T13:09:00Z`) | SUCCEEDED · провенанс: `/reference/sq_cadence_2026-07-27.md §4`; свежее подтверждение той же каденции — замер `INTRANSIT-SURFACE-LAG` (2026-08-07): `MAX(_mart_refreshed_at) = 2026-08-06 13:09:03 UTC`, тот же якорь спустя десять суток — `/reference/intransit_surface_lag_2026-08-07.md` |

Трассировка: ADR-008 §Решение (1) — дом Config ID/расписание/стратегия = `11 §SQ`; схема датасета `audit` → `/reference` (гейт Q-4); SQL → `/reference/sql/` (гейт Q-5, уже выгружен). ADR-012 §5/провенанс: живая bq show 2026-07-08, мед-реверификация расписания (выявлено дефолтное 24h, исходная формулировка ошибочно указывала «manual»).

Инвентарь флота (13 конфигураций, location `asia-east1`, проект `420804682491`) с расписаниями и
`nextRunTime` — `/reference/sq_cadence_2026-07-27.md §4` (артефакт в репо @ `9465294`), замер
2026-07-27T15:13Z, `bq` версии 2.1.35. Форма листинга заданий: `bq ls -j --all_jobs` — флаг
`--all_users` из `ADR-045 §5` на этой версии не существует (`ADR-073 §6`, superseded-in-part).
Повторный замер каденции (13–28.07, 319 заданий с целью в `marts.*`) исполнен через
`INFORMATION_SCHEMA.JOBS_BY_PROJECT` — `/reference/bq_jobs_2026-07-28.md §2`.

## §Ручные/разовые загрузки (не CF)

**`core.fact_customer_invoices`** (факт, сессия `SOURCE-MAP-INVOICES`, `2026-07-31T13:04Z…13:07Z` по
`date -u`, `reference/source_map_invoices_2026-07-30.md`): загружена ОДНИМ ручным прогоном
`2026-06-05T08:48:29Z…09:07:07Z` от личного аккаунта `ilyasbazarov4@gmail.com` — не задеплоенной CF,
не через `etl-sa@msklad-bi-prod.iam.gserviceaccount.com` (ни одна из 8 живых CF не совпадает по
принципалу). Последовательность: `CREATE TABLE` → `bq load` 4058 строк в
`core.fact_customer_invoices_stg` → `MERGE` (явный `INSERT (колонки)`, C1-совместимо) в целевую
таблицу. Повторных загрузок с той даты по `2026-07-31` не было (`distinct_load_dates=1`).

**Уточнение формулировки (`ADR-101 §2`, 2026-08-02; прежняя редакция говорила «`bq load` локального
NDJSON-файла»).** Факт: в конфигурации `LOAD`-задания отсутствует `sourceUris`, следовательно
источник не GCS. Вывод «локальный NDJSON-файл на диске» есть прочтение этого признака, а не
наблюдение файла: соседний загрузчик того же автора и периода `load_payments.py` даёт ту же картину
задания через `bigquery.Client.load_table_from_json`, при котором NDJSON-файла не возникает вовсе
(замер `INVOICES-LOADER-PROBE`, 2026-07-31). Какой из двух приёмов применён к счетам — НЕ
установлено; отсутствие файла на диске доказательством не является ни в одну сторону
(`ADR-021 §2`). Исходный файл/скрипт этой сессией не найден и не искался; его существование —
открытый вопрос владельцу (`Q-82` дополнение, `07_STATE`). Архивная строка `SOURCE-MAP-INVOICES`
в `07_ARCHIVE.md` намеренно не правится (`ADR-064`, прецедент `ADR-059 §2`): архив несёт то, что
было известно на момент закрытия строки.

## §IAM

**cf-finance (ADR-022, 2026-07-20):** `roles/run.invoker` предоставлен `etl-sa@msklad-bi-prod.iam.gserviceaccount.com`; привязка `allUsers` → `run.invoker` снята. Верификация 2026-07-20: анонимный запрос → `403`; вызов Scheduler (OIDC через тот же SA) → `200`.

**Известная не-блокирующая аномалия (Q-28, DEFER):** в логе E1-T2 (2026-07-14) при
`gcloud secrets versions access` — `Regional Access Boundary … 404 Gaia id not found for
ilyasbazarov4@gmail.com`. Прогон отработал (токен резолвился). Триггер расследования: повтор ИЛИ появление
в не-интерактивном / service-account прогоне. См. `07_STATE` Q-28.

Источник-адрес: `00_CHARTER §карта документов` стр.53; ADR-004 §Последствия (RB-05 «аспект IAM»).

## §секреты (имена)

- `bakai-fx-token` — Secret Manager, JWT-токен (Bearer auth) для Bakai OpenBanking API, используется `cf-fx` (PR-18). **TTL токена неизвестен → GAP Q-7** (см. `07_STATE`); рабочая DEFER-политика — ротация по факту 401, процедура: `RUNBOOK_v8 §17` (заморожен). `10_OPS_PLAYBOOK` не существует — `Q-35`, DEFER; указатель исправлен сессией `FX-OUTBOUND-COVERAGE-ADJ`.
- `msklad-token` — Secret Manager, используется `cf-finance` (`MSKLAD_TOKEN`, PR-13).
- `telegram-bot-token` — Secret Manager, Telegram Bot API token, используется `cf-alert` (`TELEGRAM_BOT_TOKEN`, факт 2026-08-01, `reference/infra_facts_sweep_2026-08-01.md §Q-12`).
- `telegram-chat-id` — Secret Manager, ID Telegram-чата для доставки, используется `cf-alert` (`TELEGRAM_CHAT_ID`, факт 2026-08-01, `reference/infra_facts_sweep_2026-08-01.md §Q-12`).

Источник-адрес: `00_CHARTER §карта документов` стр.53; ADR-004 §Последствия (PR-18 «cf-fx URL/секрет», PR-13, `cf-alert` — `INFRA-FACTS-LANDING`).

---

**Вне scope этой сессии (M-P4-A-03):** URL/ревизия самих CF `cf-fx`/`cf-facts` (не зафиксированы в источнике — остаются пустыми слотами); `10_OPS_PLAYBOOK`; схема датасета `audit` (Q-4); IAM (RB-05, не в scope A-03).
