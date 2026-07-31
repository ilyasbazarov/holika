# SOURCE-MAP-INVOICES — принципал/механизм загрузки `core.fact_customer_invoices`

**Дата:** 2026-07-30 (локальная, Бишкек) · **Задача:** `SOURCE-MAP-INVOICES` · **Класс:** A
**Провенанс:** сессия Claude Code, дерево `worktrees/SOURCE-MAP-INVOICES`, ветка `s/SOURCE-MAP-INVOICES`,
база `git rev-parse HEAD` = `ea431411721c7f4d38edcd3e9b1b5e011116c1dd` на момент старта сессии.

Все скрипты и полные (неусечённые) логи — `reference/_scratch_SOURCE-MAP-INVOICES_2026-07-30/`.

---

## 1. Провенанс прогонов

- Проект: `msklad-bi-prod`. Регион для `INFORMATION_SCHEMA.JOBS_BY_PROJECT` и `bq show -j`: `asia-east1`
  (совпадает с методом `FX-MAY-WINDOW` D2(б)).
- `gcloud`/`bq` — аккаунт сессии: `ilyasbazarov4@gmail.com` (личный аккаунт владельца, тот же, что
  используется во всех прочих discovery-сессиях класса A этого проекта).
- UTC-якоря всех шести прогонов (полные логи — `step{1..6}_run.log` в scratch-каталоге):
  - Шаг 1 (`_loaded_at`): `2026-07-31T13:04:06Z` → `2026-07-31T13:04:25Z`
  - Шаг 2 (job history цели): `2026-07-31T13:05:06Z` → `2026-07-31T13:05:12Z`
  - Шаг 3 (`bq show -j`, детали двух заданий): `2026-07-31T13:05:26Z` → `2026-07-31T13:05:48Z`
    (первая попытка без `--location` дала `Not found` для обоих job ID — гэп наблюдения, не факт
    «заданий нет»; закрыт повтором с `--location=asia-east1`, см. `step3_run.log` целиком — обе попытки
    включены)
  - Шаг 4 (инвентарь CF service accounts): `2026-07-31T13:06:08Z` → `2026-07-31T13:06:14Z`
  - Шаг 5 (job history staging-таблицы, расширение за пределы буквальных шагов брифа — обоснование в §6):
    `2026-07-31T13:06:40Z` → `2026-07-31T13:06:46Z`
  - Шаг 6 (`bq show -j` для `LOAD`-задания staging): `2026-07-31T13:07:28Z` → `2026-07-31T13:07:33Z`
- Каждый прогон открывается и закрывается `date -u` + `gcloud auth list` (`ADR-055 §3/§4`) — аккаунт
  не менялся ни разу за все шесть прогонов.

---

## 2. Граница `_loaded_at` (Шаг 1)

```json
[
  {
    "row_count": "4058",
    "min_loaded_at": "2026-06-05 09:06:57",
    "max_loaded_at": "2026-06-05 09:06:57",
    "distinct_load_dates": "1"
  }
]
```

Факт: вся таблица (4058 строк) несёт ОДИН и тот же `_loaded_at` — таблица загружена одним батчем, не
инкрементальным ETL-циклом. Это сужает Шаг 2 к узкому окну вокруг `2026-06-05`, вместо полного горизонта.

---

## 3. История заданий на целевую таблицу (Шаг 2)

Запрос — без сужения по времени (полный доступный горизонт `INFORMATION_SCHEMA.JOBS_BY_PROJECT`,
`destination_table.dataset_id='core' AND table_id='fact_customer_invoices'`). Выдача НЕ пуста — два
задания, оба датированы `2026-06-05`, оба совпадают с границей Шага 1:

| job_id | user_email | creation_time | job_type | statement_type |
|---|---|---|---|---|
| `bqjob_r15d696c9f4d48773_0000019e96f835a9_1` | `ilyasbazarov4@gmail.com` | `2026-06-05 08:48:29` | QUERY | `CREATE_TABLE` |
| `9026b571-70bc-475d-84eb-06a393692929` | `ilyasbazarov4@gmail.com` | `2026-06-05 09:07:07` | QUERY | `MERGE` |

Полный вывод запроса — `step2_run.log`.

---

## 4. Квалификация находки (Шаг 3)

**Исход: (3) из трёх — найдены задания, но от `user_email` личного аккаунта владельца
(`ilyasbazarov4@gmail.com`), не сервис-аккаунта.** Не деплой CF, не автоматика — разовый ручной прогон.

### 4.1 Задание 1 — `CREATE TABLE` (`bq show -j`, `step3_run.log`)

- `principal_subject`: `"user:ilyasbazarov4@gmail.com"`
- `creation_time` (statistics): `1780649309837` мс epoch = `2026-06-05 08:48:29 UTC`
- Полный текст запроса:
  ```sql
  CREATE TABLE IF NOT EXISTS `msklad-bi-prod.core.fact_customer_invoices`
  (
    invoice_id        STRING    NOT NULL,
    invoice_name      STRING,
    moment            DATE,
    agent_id          STRING,
    agent_name        STRING,
    state_id          STRING,
    state_name        STRING,
    sum_kgs           FLOAT64,
    payed_sum_kgs     FLOAT64,
    unpaid_sum_kgs    FLOAT64,
    payment_planned   DATE,
    sales_channel_id  STRING,
    sales_channel_name STRING,
    _loaded_at        TIMESTAMP
  );
  ```
  Схема совпадает буквально с `reference/schema_dump_2026-07-28.md §core.fact_customer_invoices`
  (14 колонок, те же имена/типы) — DDL этого задания и есть источник текущей схемы таблицы.

### 4.2 Задание 2 — `MERGE` (`bq show -j`, `step3_run.log`)

- `principal_subject`: `"user:ilyasbazarov4@gmail.com"`
- `creation_time` (statistics): `1780650427040` мс epoch = `2026-06-05 09:07:07 UTC`
- `dmlStats`: `insertedRowCount=4058`, `updatedRowCount=0`, `deletedRowCount=0` — чистая вставка (таблица
  была только что создана Заданием 1, строк для UPDATE не существовало).
- Источник (`referencedTables`): `msklad-bi-prod.core.fact_customer_invoices_stg` — staging-таблица.
- Полный текст запроса:
  ```sql
  MERGE `msklad-bi-prod.core.fact_customer_invoices` T
  USING `msklad-bi-prod.core.fact_customer_invoices_stg` S
  ON T.invoice_id = S.invoice_id
  WHEN MATCHED THEN UPDATE SET
    T.invoice_name       = S.invoice_name,
    T.moment             = S.moment,
    T.agent_id           = S.agent_id,
    T.agent_name         = S.agent_name,
    T.state_id           = S.state_id,
    T.state_name         = S.state_name,
    T.sum_kgs            = S.sum_kgs,
    T.payed_sum_kgs      = S.payed_sum_kgs,
    T.unpaid_sum_kgs     = S.unpaid_sum_kgs,
    T.payment_planned    = S.payment_planned,
    T.sales_channel_id   = S.sales_channel_id,
    T.sales_channel_name = S.sales_channel_name,
    T._loaded_at         = S._loaded_at
  WHEN NOT MATCHED THEN INSERT (
    invoice_id, invoice_name, moment, agent_id, agent_name,
    state_id, state_name, sum_kgs, payed_sum_kgs, unpaid_sum_kgs,
    payment_planned, sales_channel_id, sales_channel_name, _loaded_at
  ) VALUES (
    S.invoice_id, S.invoice_name, S.moment, S.agent_id, S.agent_name,
    S.state_id, S.state_name, S.sum_kgs, S.payed_sum_kgs, S.unpaid_sum_kgs,
    S.payment_planned, S.sales_channel_id, S.sales_channel_name, S._loaded_at
  )
  ```
  Наблюдение (не входит в scope этой задачи, но отмечается фактом): `WHEN NOT MATCHED THEN INSERT`
  несёт явный список колонок, не `INSERT ROW` — соответствует C1/`ADR-030`, если бы этот запрос был
  частью нового кода проекта (он не является — разовый ручной прогон, датированный до принятия ADR-030,
  которое датировано позже; упомянуто для полноты, не как претензия).

### 4.3 Расширение — происхождение самой staging-таблицы (Шаг 5, вне буквальных шагов брифа)

За пределами Шага 2/3 брифа (который адресует только `core.fact_customer_invoices`), этой сессией
дополнительно, тем же read-only методом, проверено происхождение `core.fact_customer_invoices_stg` —
единственного источника `MERGE` выше. Обоснование расширения — §6 ниже.

`INFORMATION_SCHEMA.JOBS_BY_PROJECT` для `dataset_id='core' AND table_id='fact_customer_invoices_stg'`
(`step5_run.log`) — одно задание:

| job_id | user_email | creation_time | job_type |
|---|---|---|---|
| `fcd260f7-1fef-42ba-bfb1-101fd0f4b7ca` | `ilyasbazarov4@gmail.com` | `2026-06-05 09:07:05` | LOAD |

`bq show -j` (`step6_run.log`) для этого `LOAD`-задания:

- `principal_subject`: `"user:ilyasbazarov4@gmail.com"`
- `sourceFormat`: `NEWLINE_DELIMITED_JSON`, `writeDisposition`: `WRITE_TRUNCATE`
- `load.inputFiles`: `1`, `load.inputFileBytes`: `2367736`, `load.outputRows`: `4058`, `load.badRecords`: `0`
- **Поле `sourceUris` в конфигурации задания ОТСУТСТВУЕТ** (`step6_run.log`, секция
  `configuration.load` содержит `destinationTable`/`schema`/`sourceFormat`/`writeDisposition`, без
  `sourceUris`). Это наблюдение, не интерпретация: `bq load` из GCS обычно несёт `sourceUris` в конфиге
  задания; отсутствие поля указывает на загрузку из ЛОКАЛЬНОГО файла (multipart upload при вызове
  `bq load` без `gs://`-пути), а не из GCS-объекта. Прямого поля «путь к локальному файлу» BigQuery API
  не сохраняет, поэтому имя/расположение исходного NDJSON-файла этим методом не восстановимо.

**Хронология одной сессии владельца, `2026-06-05`:**
`08:48:29` CREATE TABLE → `09:06:57` (`_loaded_at` в данных, проставлен исходным скриптом/файлом до
загрузки) → `09:07:05` LOAD в `_stg` (1 локальный NDJSON-файл, 4058 строк) → `09:07:07` MERGE в целевую
таблицу (чистая вставка 4058/4058). Все четыре временные точки укладываются в 19-минутное окно одной
ручной сессии.

---

## 5. Сверка с инвентарём CF (Шаг 4)

```
NAME                SERVICE_ACCOUNT_EMAIL
cf-alert            etl-sa@msklad-bi-prod.iam.gserviceaccount.com
cf-dim              etl-sa@msklad-bi-prod.iam.gserviceaccount.com
cf-dq               etl-sa@msklad-bi-prod.iam.gserviceaccount.com
cf-facts            etl-sa@msklad-bi-prod.iam.gserviceaccount.com
cf-finance          etl-sa@msklad-bi-prod.iam.gserviceaccount.com
cf-fx               etl-sa@msklad-bi-prod.iam.gserviceaccount.com
cf-inventory        etl-sa@msklad-bi-prod.iam.gserviceaccount.com
cf-loss-commission  etl-sa@msklad-bi-prod.iam.gserviceaccount.com
```

Восемь живых CF — все используют один и тот же сервис-аккаунт `etl-sa@msklad-bi-prod.iam.
gserviceaccount.com`. Ни одна из восьми НЕ совпадает с `user_email` найденных заданий
(`ilyasbazarov4@gmail.com` — личный аккаунт, не сервис-аккаунт). **Это прямо подтверждает (не просто не
опровергает), что ни одна из живых CF не является механизмом загрузки** — принципал заданий структурно
отличается от принципала любой из восьми CF (пользовательская личность vs сервис-аккаунт), совпадения по
account email нет и не может быть в принципе (сверка не «сужает круг подозреваемых», а **исключает всех
восьмерых как класс**, поскольку ни у одной из них нет и не может быть личного `user_email` вместо
сервис-аккаунта в задеплоенной конфигурации).

---

## 6. Итоговая квалификация

**Исход (3):** `core.fact_customer_invoices` загружена ОДНИМ ручным/бэкфилл-прогоном
`2026-06-05T08:48:29Z…09:07:07Z` от личного аккаунта владельца (`ilyasbazarov4@gmail.com`), не через
задеплоенную Cloud Function и не через сервис-аккаунт `etl-sa@…`. Последовательность:
`CREATE TABLE` (задание BigQuery) → `bq load` локального NDJSON-файла (4058 строк) в промежуточную
`core.fact_customer_invoices_stg` → `MERGE` из staging в целевую таблицу с явным списком колонок.
С `2026-06-05` по сегодня (`2026-07-31`) повторных загрузок НЕ было (`distinct_load_dates=1` в Шаге 1
подтверждает это независимо от истории заданий).

Это НЕ карта происхождения (`ADR-079 §2`: документ МойСклада → поле → колонка) — она этой задачей не
выводится по построению (нет кода загрузчика, есть только SQL-задания BigQuery). Установлен принципал
и механизм, не семантика полей.

Расширение Шага 5/6 (§4.3) обосновано так: цель задачи (`SOURCE-MAP-INVOICES` §Цель) явно включает
«при наличии — исходный GCS-объект для LOAD-заданий», и очевидный следующий вопрос после нахождения
`MERGE` из staging-таблицы — откуда сама staging-таблица. Это тот же read-only метод
(`INFORMATION_SCHEMA.JOBS_BY_PROJECT` + `bq show -j`), тот же класс A, ничего не пишет в облако; отказ
проверить очевидное продолжение того же запроса создал бы неполный ответ на вопрос «как загружена
таблица», который прямо входит в Цель задачи. Карта полей/кода это расширение не даёт и не пытается дать.

---

## 7. Рекомендация следующего шага

Код-загрузчика в привычном смысле (Cloud Function, скрипт в код-репо) для этой таблицы, по-видимому, **не
существовал как задеплоенный артефакт** — это был ручной прогон `bq load` + `MERGE` от личного аккаунта.
Единственный шанс восстановить логику формирования исходного NDJSON-файла (соответствие
`entity/invoiceout` → 14 колонок таблицы) — это **не** код CF (искать там бессмысленно, `SOURCE-MAP-REST`
уже это исключил, а эта сессия исключила независимо через несовпадение принципала), а:

- локальный/Cloud Shell файл (ноутбук, разовый Python-скрипт, ручной SQL), которым владелец сформировал
  NDJSON `2026-06-05` — если он ещё существует на диске Cloud Shell или локальной машине владельца;
- либо признание, что этот код не сохранился нигде и восстановить карту полей `entity/invoiceout` →
  колонка придётся заново, с нуля, обратной инженерией по самим данным + документации API МойСклада
  (без ссылки на утерянный скрипт).

**Прямой вопрос владельцу:** существует ли где-то (диск Cloud Shell, ноутбук, локальная машина) скрипт
или файл `2026-06-05`, которым были сформированы исходные 4058 строк для `bq load` в
`core.fact_customer_invoices_stg`? Если да — это открывает второй порядок discovery (снятие кода тем же
методом, что `CODE-REPO-STANDUP`/`SOURCE-MAP-SALES`, но отдельной задачей). Если нет — `Q-82` в части
«код навсегда утерян» становится кандидатом решения уровня `06` (см. `NEW_DECISIONS` в session-блоке,
`proposed`, не применяется без апрува).
