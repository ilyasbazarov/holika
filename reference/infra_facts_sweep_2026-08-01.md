# INFRA-FACTS-SWEEP — сводный артефакт, 2026-08-01

**Задача:** `INFRA-FACTS-SWEEP` (класс A, `ADR-091 §10`). Закрытие семи мелких read-only гэпов из
`07_STATE.md §Открытые вопросы / GAP-реестр`: `Q-6`, `Q-11`, `Q-12`, `Q-13`, `Q-14`, `Q-47`, `Q-55`.
Все команды/запросы — read-only (`describe`/`SELECT`), не-идемпотентных операций в этой сессии нет.

Сырые логи: `reference/_scratch_INFRA-FACTS-SWEEP_2026-08-01/` (`step0`…`step4`).

---

## Q-6 — актуальная ревизия `cf-dq` после T-1-фикса

**Команда:** `gcloud functions describe cf-dq --project=msklad-bi-prod --region=asia-east1 --gen2`
(лог: `step1_gcloud_describe.log:9-51`).

**Выдержка:**
```
revision: cf-dq-00007-hot
updateTime: '2026-07-30T10:04:58.501779835Z'
createTime: '2026-05-07T12:53:10.388923634Z'
state: ACTIVE
serviceAccountEmail: etl-sa@msklad-bi-prod.iam.gserviceaccount.com
timeoutSeconds: 120
uri: https://cf-dq-xw5u2boozq-de.a.run.app
```

**Вывод:** факт снят. Актуальная ревизия — **`cf-dq-00007-hot`**, `updateTime = 2026-07-30T10:04:58Z` —
новее, чем последняя известная ранее `cf-dq-00006-lac` (которая предшествовала T-1-фиксу 2026-06-24).
`--gen2`-флаг подошёл (функция gen2, `environment: GEN_2`), фоллбэк без флага дал идентичный вывод.
Само тело T-1-фикса этим замером не читалось — снят только факт ревизии/даты, что и было методом строки.

---

## Q-11 — свежая выгрузка бизнес-метрик (X/Y/Z, ABC)

**Запрос:** `SELECT xyz_class, COUNT(*) FROM marts.abc_xyz GROUP BY xyz_class ORDER BY xyz_class` (+
аналогично по `abc_class`, + `COUNT(*)` всей таблицы) — лог `step4_sql_queries.log`.

**Выдержка:**
```
xyz_class=X cnt=28
xyz_class=Y cnt=164
xyz_class=Z cnt=338
(total marts.abc_xyz = 530 строк)

abc_class=A cnt=112
abc_class=B cnt=151
abc_class=C cnt=267
```

**Вывод:** факт снят, зафиксировано РАСХОЖДЕНИЕ с датированными 2026-06-05 цифрами `07_STATE`
(X=39, Y=148, Z=439 — сумма 626): свежая выгрузка даёт X=28, Y=164, Z=338 (сумма 530). Расхождение
не сглаживается: и распределение, и общее число строк изменились. Причина изменения (пересчёт марта,
изменение состава товаров, окно 90 дней сдвинулось) этим замером не устанавливалась — вне метода строки
Q-11 (метод — «свежая выгрузка», не диагностика причины дрейфа).

---

## Q-12 — `cf-alert`: URL/конфиг/Telegram

**Команда:** `gcloud functions describe cf-alert --project=msklad-bi-prod --region=asia-east1 --gen2`
(лог: `step1_gcloud_describe.log:97-147`).

**Выдержка:**
```
revision: cf-alert-00001-bej
createTime: '2026-05-13T12:23:18.665754631Z'
updateTime: '2026-07-30T10:04:58.439199216Z'
state: ACTIVE
uri: https://cf-alert-xw5u2boozq-de.a.run.app
url: https://asia-east1-msklad-bi-prod.cloudfunctions.net/cf-alert
serviceAccountEmail: etl-sa@msklad-bi-prod.iam.gserviceaccount.com
timeoutSeconds: 30
secretEnvironmentVariables:
  - key: TELEGRAM_BOT_TOKEN, secret: telegram-bot-token, version: latest
  - key: TELEGRAM_CHAT_ID,  secret: telegram-chat-id,  version: latest
```

**Вывод:** факт снят полностью. `cf-alert` — gen2 HTTP CF, единственная ревизия `00001-bej` (с момента
создания, ни разу не редеплоена), Telegram bot token/chat id читаются из секретов (имена — не значения:
`telegram-bot-token`, `telegram-chat-id`). Placeholder узла `01_ARCHITECTURE.md §топология` (`GAP Q-12`)
закрывается этими фактами; правка самого `01_ARCHITECTURE.md`/`11_INFRA_FACTS.md` — вне scope этой
сессии (класс A пишет только в `/reference`).

---

## Q-13 — `msklad-pipeline-weekly`: состав шагов

**Команда:** `gcloud workflows describe msklad-pipeline-weekly --project=msklad-bi-prod
--location=asia-east1` (лог: `step1_gcloud_describe.log:199-420`).

**Выдержка (порядок шагов из `sourceContents`):**
```
init → step_dim → step_fx → step_facts(mode=weekly) → step_dq → parse_dq_result → check_dq
  → step_promote(mode=promote, window_days=90) → step_purchases(mode=purchases)
  → step_returns(mode=returns, window_days=90) → done
revisionId: 000003-fa9, revisionCreateTime: 2026-05-11T07:41:00Z
updateTime: 2026-07-30T10:04:58.556441498Z
serviceAccount: etl-sa@msklad-bi-prod.iam.gserviceaccount.com
```
Вызываемые URL: `cf-dim`, `cf-fx`, `cf-facts` (трижды, режимами `weekly`/`promote`/`purchases`/`returns` —
именно `cf-facts` вызывается четыре раза с разными `mode`), `cf-dq`. Все вызовы — `http.post` с `auth:
type: OIDC`. `step_purchases` и `step_returns` — non-blocking (собственный `except`/`raise_*`, не входят
в цепочку `check_dq`, комментарий в `sourceContents` явно называет `step_purchases` «не блокирует
promote при ошибке» и `step_returns` «0 записей за окно — не ошибка»).

**Вывод:** факт снят полностью, включая полный текст `sourceContents` (поле присутствует). Состав шагов
weekly-DAG документирован впервые — `01_ARCHITECTURE.md §DAG` до этой сессии несёт только
hourly-workflow.

---

## Q-14 — процедура полной пересборки `core` из GCS raw

**Метод:** read-only разведка (код снапшотов + история BigQuery jobs), без восстановления процедуры
догадкой (запрещено брифом).

**Шаг А — поиск кода, читающего `GCS_RAW` обратно в BigQuery.** `grep -rn "GCS_RAW"
reference/code/*/*.py` показывает использование `GCS_RAW = "msklad-raw-msklad-bi-prod"` только как
**цель записи** (`upload_ndjson_gz(gcs, GCS_RAW, ...)`) в `cf-facts/main.py` (4 вхождения) и
`cf-inventory/main.py` (1 вхождение). Ни одного вызова чтения (`download_blob`, `blob.download_*`,
`storage.Client().get_bucket(...).blob(...).download_*`) в этих файлах или где-либо ещё в снапшоте нет —
`grep -rln "backfill\|rebuild\|full_reload\|reload_from_gcs\|read_gcs\|download_blob\|blob.download"
reference/code/` дал пустую выдачу.

**Шаг Б — история BigQuery LOAD-заданий в `core.*`.** Запрос по `INFORMATION_SCHEMA.JOBS_BY_PROJECT`
(`region-asia-east1` и `region-US`, `--location` указан явно на обеих, `ADR-021 §2`) по всем
`job_type = "LOAD"` с целью `core.*` за весь доступный период (лог `step3_q14_bq_load_jobs.log`, 115
строк-заданий) даёт:
```
dest_table распределение: dim_fx_rates=5, dim_products=2, dim_counterparties=1, dim_employees=1,
  fact_inventory=21, fact_purchases=65, fact_returns=3, fact_sales_profit=2
user_email: bootstrap-sa@…=12, etl-sa@…=87, ilyasbazarov4@gmail.com=1
диапазон creation_time: 2026-04-29 18:40:07 … 2026-05-21 05:04:13 (location=asia-east1)
region-US: [] (0 LOAD-заданий в core из US)
```
Первая попытка запроса (по тексту `query LIKE '%gcs%'`) дала пустую выдачу (`step2_q14_bq_jobs.log`) —
эта форма ошибочна по построению: BigQuery LOAD-задания не несут SQL-текста в поле `query`
(`INFORMATION_SCHEMA.JOBS_BY_PROJECT` не парсит `sourceUris` в текст), поэтому пустой результат был бы
неверно прочитан как «заданий нет» (`ADR-021 §2`/`ADR-044`). Исправлено фильтром по `job_type = "LOAD"`
напрямую — это и дало содержательный результат выше.

**Вывод:** факт (отрицательный, но обоснованный) — **процедура «Очистить core → Запустить пересборку
из GCS» (`RUNBOOK_v8.md §11.2/§11.3`) не документирована нигде в репо и не восстановлена этим замером.**
Все LOAD-задания в `core.*` сосредоточены в узком окне `2026-04-29…2026-05-21` (бутстрап проекта, по
большей части от `bootstrap-sa`/`etl-sa`) и не появляются позже — то есть после мая 2026 механизм
«LOAD из GCS в core» не использовался ни разу за весь измеренный период. Раздел `§11` источника
несёт только заголовки шагов без команд (`RUNBOOK_v8.md:576`, дословно: «**11.2.** Очистить core →
**11.3.** Запустить пересборку из GCS.») — это подтверждено чтением, реконструкция процедуры с нуля
вне scope этой задачи (связано с `Q-3`, отдельным гэпом).

---

## Q-47 — Loss: не-KGS документы, укладка артефакта

**Задача НЕ переоткрывает** DEFER-решение `E1-T1-INGEST-ADJ` — только кладёт SQL/лог замера в
`/reference` (условие строки `Q-47`, `07_STATE.md`).

**Запросы (лог `step4_sql_queries.log`):**
```sql
SELECT COUNT(*) AS total_rows FROM `msklad-bi-prod.core.fact_loss`;
SELECT COUNT(*) AS non_kgs_rows FROM `msklad-bi-prod.core.fact_loss` WHERE currency_code != 'KGS';
```
Имя колонки валюты сверено с живой схемой ПЕРЕД запуском (`step0_schema_check.log`): `core.fact_loss`
несёт колонку `currency_code` (STRING) — подтверждено, не предположение.

**Выдержка:**
```
total_rows   = 129
non_kgs_rows = 0
```

**Вывод:** факт снят, артефакт уложен. **0 из 129** документов — не-KGS. Прежний замер (сессия
`E1-T1-MECH-INGEST`, 2026-07-23) фиксировал «0 из 128» — таблица выросла на одну строку с той даты
(129 против 128), само соотношение «0 не-KGS» не изменилось. Рост на одну строку зафиксирован как
факт, не сглажен: причина роста (новый документ списания, поздняя догрузка) этим замером не
устанавливалась — вне метода строки. DEFER-статус `Q-47` не переоткрывается.

---

## Q-55 — три `COUNTIF` по `core.fact_loss`

**Задача НЕ переоткрывает** `ADR-036` независимо от результата (условие строки `Q-55`) — только
замеряет и фиксирует число.

**Запрос (лог `step4_sql_queries.log`):**
```sql
SELECT
  COUNTIF(project_id IS NOT NULL) AS project_id_nn,
  COUNTIF(sales_channel_id IS NOT NULL) AS sales_channel_id_nn,
  COUNTIF(agent_name IS NOT NULL) AS agent_name_nn,
  COUNT(*) AS total
FROM `msklad-bi-prod.core.fact_loss`;
```

**Выдержка:**
```
project_id_nn        = 0
sales_channel_id_nn  = 0
agent_name_nn        = 0
total                = 129
```

**Вывод:** факт снят. Все три `COUNTIF` дали **0** из 129 строк — условие переоткрытия `ADR-036`
(`07_STATE.md`: «любое ненулевое значение ⇒ `ADR-036` переоткрывается») **не наступило**. `ADR-036` и
SQL марта этой сессией не тронуты, переоткрытие не производится.

---

## Провенанс

Все сырые логи — `reference/_scratch_INFRA-FACTS-SWEEP_2026-08-01/`:
- `step0_schema_check.sh`/`.log` — живая схема `core.fact_loss` (колонка `currency_code` подтверждена)
  и `marts.abc_xyz` (колонки `xyz_class`/`abc_class` подтверждены) перед запуском SQL из Q-47/Q-55/Q-11.
- `step1_gcloud_describe.sh`/`.log` — Q-6 (`cf-dq`), Q-12 (`cf-alert`), Q-13 (`msklad-pipeline-weekly`).
- `step2_q14_bq_jobs.sh`/`.log` — первая (ошибочная по построению) попытка Q-14, оставлена как провенанс
  найденного методического дефекта, не удалена (`ADR-043`).
- `step3_q14_bq_load_jobs.sh`/`.log` — исправленный запрос Q-14 (фильтр `job_type = "LOAD"`).
- `step4_sql_queries.sh`/`.log` — Q-47, Q-55, Q-11.

Каждый скрипт несёт `date -u`/`gcloud auth list` первой и последней командой (`ADR-055 §3/§4`).
