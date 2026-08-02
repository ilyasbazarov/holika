=== SESSION LOG · 2026-08-02 · CORE-FRESHNESS-SWEEP ===

## SESSION_LOG  (→ append в /docs, опц. CHANGELOG)
- Задача: CORE-FRESHNESS-SWEEP — сплошной прогон свежести по всем таблицам `core`/`marts`, база `5563e5e935b6350bbde07fe2a92cca711f891a96`
- Сделано:
  - Инвентарь `INFORMATION_SCHEMA.TABLES`+`__TABLES__` по `core`(15)/`marts`(11) = 26 таблиц, регион `asia-east1` явно
  - Съём колонок времени всех 26 таблиц (`INFORMATION_SCHEMA.COLUMNS`); поймана и не примирена ловушка умолчательного лимита `bq query` (100 строк, `rc=0`, правдоподобно на вид) — перезапущено с `--max_rows`, подтверждено независимым `COUNT(*)` (183/15 core, 212/11 marts)
  - MIN/MAX/COUNT(DISTINCT) по колонке времени каждой из 21 таблицы, у которой такая колонка есть
  - `INFORMATION_SCHEMA.JOBS_BY_PROJECT` по подозрительным/единично-значным таблицам — найдена остановка часового `cf-facts` (promote `fact_sales_profit` + `fact_purchases`, последний прогон `2026-08-01 17:02-17:05Z`, ни одного задания за следующие ~18.5ч, при этом `cf-dim` продолжает работать ежечасно без перерыва) и пропуск двух воскресений у еженедельного `fact_returns` (последний прогон `2026-07-19`, ожидались `07-26` и `08-02`)
  - Найдена вторая, ранее неизвестная заморозка: `core.dim_metadata_mappings` — единственное значение `last_verified` на всех 19 строках с момента создания `2026-04-29` (94д 16ч), при том что три сестринские таблицы того же `cf-dim` (`dim_products`/`dim_counterparties`/`dim_employees`) обновляются ежечасно; `__TABLES__` подтверждает `last_modified_time = creation_time` день-в-день
  - Найдена третья заморозка без установленного владельца в топологии: `core.fact_sales_profit_byvariant_backup` (единственная загрузка `2026-05-03`, 91д, не названа ни за одной CF — код-константа `CORE_BYVARIANT_BCK`)
  - Артефакт `reference/core_freshness_sweep_2026-08-02.md` — полный вердикт по всем 26 таблицам, включая 5, не проверяемых этим методом (нет колонки времени), с явным разбором, почему вторичный сигнал `last_modified_time` хранилища для CREATE-OR-REPLACE витрин не заменяет метод (тот же эффект маскировки, что уже был на счетах)
- Команды/логи ключевые: `reference/_scratch_CORE-FRESHNESS-SWEEP_2026-08-02/{step1_inventory.sh,step1_run.log,step2_columns.sh,step2_run.log,step3_age.sh,step3_run.log,step4_job_history.sh,step4_run.log,step4b_dim_cadence.sh,step4b_run.log,columns_core_full.json,columns_marts_full.json,time_columns_summary.json}`; усечённые `columns_core.json`/`columns_marts.json`/`.err` сохранены как провенанс пойманной ловушки лимита
- Отклонения от плана: нет — пять шагов брифа исполнены по одному скрипту на шаг; ловушка лимита `bq query` обнаружена и закрыта в рамках Шага 2, не потребовала выхода за пределы брифа

## STATE_PATCH  (→ применить к 07_STATE.md)
- Задача CORE-FRESHNESS-SWEEP: READY → DONE
- Стенд-ап (ЗАМЕНЯЕТ блок `### Стенд-ап` в `07_STATE` целиком, НЕ дописывается, ровно пять строк):
  - Прошлый шаг: сплошной прогон свежести `core`/`marts` закрыт (`CORE-FRESHNESS-SWEEP`) — из 26 таблиц 15 живых, 3 отстают, 3 заморожены (включая уже известную `fact_customer_invoices`), 5 не проверяемы этим методом; артефакт `reference/core_freshness_sweep_2026-08-02.md`
  - Где мы: заморозка счетов не единична — найдены ещё две (`dim_metadata_mappings` 94д, `fact_sales_profit_byvariant_backup` 91д) и текущая остановка часового `cf-facts` (`fact_sales_profit`/`fact_purchases`, ~18.5ч без промоута) плюс пропуск двух воскресений у `fact_returns`; причины ни одной находки не устанавливались (вне scope)
  - Следующий шаг: архитекторская триаж находок этого замера (какие требуют немедленного внимания владельца, какие идут в реестр как новые задачи/гэпы) — решение не принято этой сессией (класс A, вне мандата); параллельно без изменений — все задачи предыдущего стенд-апа (`SALES-CONSIGNMENT-REVENUE`, `SALES-PERIMETER-EXTEND`, `SALES-REFRESH-WINDOW`, `FX-MAY-WINDOW-D1-TAIL`, `INGEST-CURRENCY-ASSERT` шаги 1-2, подготовка `INGEST-MOMENT-ZONE-FIX`, тексты Looker Studio, `DQ-SOURCE-CAPTURE`, `PARALLEL-CHECK-BLOCK-END`)
  - Развилки на владельце: без изменений — `CODE-REPO-STANDUP` шаг 2b; ответ клиента по часовому поясу (`MSKLAD-TZ-PROPOSAL`); мандат класса B на `AUDIT-SNAPSHOT-FIX-EMPLOYEES`/`AUDIT-COUNTERPARTIES-SNAPSHOT-RETIRE`; НОВОЕ — нужна ли немедленная реакция на остановку часового `cf-facts` (промоут `fact_sales_profit`/`fact_purchases` не идёт с `2026-08-01 17:02Z`, это отдельно от паритета — операционный сбой текущего пайплайна)
  - Счётчик: пары реестра 2/7 сходятся · измерено 7/7 · строк реестра на критическом пути 23 из 63 · Epic M 5/7 фаз
- Подробности для модели: Полный ход — `reference/core_freshness_sweep_2026-08-02.md` (не пересказывается). Ключевое, без чего сломается следующая сессия: (i) `bq query` без `--max_rows` молча обрезает вывод до 100 строк с `rc=0` — при работе с `INFORMATION_SCHEMA.COLUMNS`/аналогичными широкими запросами обязательно ставить явный `--max_rows` и сверять с независимым `COUNT(*)`, иначе получится правдоподобный, но неполный список таблиц; (ii) единственное значение колонки времени на всю таблицу («`n_distinct=1`») само по себе НЕ есть признак заморозки — для таблиц с ежедневным `TRUNCATE+reload` (`fact_loss`, `fact_commissionreportin`, все `_mart_refreshed_at`-витрины) это ожидаемая форма; различитель — меняется ли это единственное значение ото дня ко дню (заморожена = НЕТ, живая = ДА); (iii) часовой `cf-facts` (промоут `fact_sales_profit` + загрузка `fact_purchases`) не отработал ни разу с `2026-08-01T17:02-17:05Z` по момент замера (`2026-08-02T11:45Z`), при этом соседний `cf-dim` работает без пропусков — это ДЕЙСТВУЮЩАЯ остановка текущего пайплайна, не историческая находка, и она не была известна репо до этой сессии; (iv) `fact_returns` (еженедельный полный reload по воскресеньям 01:00 UTC) пропустил `07-26` и сегодняшнее `08-02`; (v) 7 canonical marts-SQ (`abc_xyz`/`gmroi`/`gmroi_by_folder`/`in_transit`/`inventory_health`/`supplier_price_history`/`weight_flow`) не несут задокументированного расписания в `11_INFRA_FACTS §SQ` — оценка их свежести в артефакте сделана по абсолютному возрасту, не по сравнению с эталонным периodом.
- Новые открытые вопросы: `CORE-FRESHNESS-DIM-METADATA` (заморозка `core.dim_metadata_mappings` с `2026-04-29`, владелец по топологии — `cf-dim`, причина не установлена) · `CORE-FACTS-HOURLY-STALL` (действующая остановка часового промоута `fact_sales_profit`/`fact_purchases` с `2026-08-01T17:02Z`, требует внимания раньше прочих находок этой задачи — операционный сбой, не архивная находка) · `FACT-RETURNS-WEEKLY-GAP` (пропуск двух воскресений `07-26`/`08-02` у еженедельного reload `fact_returns`) · `FACT-SALES-BYVARIANT-BACKUP-OWNER` (таблица `fact_sales_profit_byvariant_backup` заморожена с `2026-05-03`, владелец/ожидаемая частота нигде не названы — решить, это разовый бэкап или пропущенный загрузчик)
- Блокеры: нет
- updated_at: 2026-08-02
- обновил: исполнитель (сессия: CORE-FRESHNESS-SWEEP)

## NEW_DECISIONS  (→ append в 06_DECISIONS_LOG.md как ADR; "нет" если нет)
нет

## NEW_CONVENTIONS  (→ предложение правки 05; "нет" если нет)
нет

=== END SESSION ===
