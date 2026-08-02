=== SESSION LOG · 2026-08-02 · INVOICES-STALENESS-PROBE ===

## SESSION_LOG  (→ append в /docs, опц. CHANGELOG)
- Задача: INVOICES-STALENESS-PROBE — read-only замер, пополняется ли `core.fact_customer_invoices`
  (постановка без брифа, `ADR-086 §1`; полный текст — `reference/parity_coarse_adj_2026-08-02.md §3/§4`
  на ветке `s/PARITY-COARSE-ADJ`)
- Сделано: снята схема таблицы (`bq show` + `INFORMATION_SCHEMA.COLUMNS`, 14 колонок, время загрузки —
  `_loaded_at`, время документа — `moment`); сняты `MIN`/`MAX`/`COUNT` и разбивка по годам/месяцам;
  найдены все задания BigQuery за 90 суток с целью `core.fact_customer_invoices` (регионы
  `asia-east1`/`us`) и все transfer configs (`asia-east1`/`us`); контрольный запрос по активности
  ETL в датасете `core` за 7 суток. Вердикт: таблица заморожена с `2026-06-05T09:07:07Z`, 58 суток
  до момента замера — полный разбор и все сырые числа в `reference/invoices_staleness_probe_2026-08-02.md`
- Команды/логи ключевые: `reference/_scratch_INVOICES-STALENESS-PROBE_2026-08-02/step1_run.log`,
  `step2_run.log`, `step3_run.log` (три скрипта-файла, `date -u`/`gcloud auth list` первой и последней
  командой каждого)
- Отклонения от плана: нет

## STATE_PATCH  (→ применить к 07_STATE.md)
- Задача INVOICES-STALENESS-PROBE: не заведена строкой реестра (постановка `ADR-086 §1`, разовый
  замер) → DONE, артефакт `reference/invoices_staleness_probe_2026-08-02.md`
- Стенд-ап (ЗАМЕНЯЕТ блок `### Стенд-ап` в `07_STATE` целиком, НЕ дописывается, ровно пять строк):
  - Прошлый шаг: замер `INVOICES-STALENESS-PROBE` закрыт — `core.fact_customer_invoices` заморожена
    с `2026-06-05T09:07:07Z` (единственные два BigQuery-задания за 90 суток с этой целью — `CREATE_TABLE`
    и один `MERGE`, оба в тот день; все 4058 строк несут один `_loaded_at`), артефакт
    `reference/invoices_staleness_probe_2026-08-02.md`
  - Где мы: находка меняет квалификацию пары «Счета покупателям» — недостача 468 документов и
    несравнимость сумм из `ADR-103`-адъюдикации (`PARITY-COARSE-ADJ §3`) относится к таблице,
    которая не обновлялась 58 суток; требует архитекторской переклассификации, не поштучной правки
  - Следующий шаг: адъюдикация архитектора — переклассифицировать находку пары «Счета покупателям»
    с учётом заморозки (следующий кандидат по постановке — `INVOICES-FIELD-MAP`, идёт ПОСЛЕ этого
    решения, её объём зависит от него); параллельно без изменений — `SALES-CONSIGNMENT-REVENUE`,
    `SALES-PERIMETER-EXTEND`, `SALES-REFRESH-WINDOW`, `FX-MAY-WINDOW-D1-TAIL`,
    `INGEST-CURRENCY-ASSERT` шаги 1-2, подготовка `INGEST-MOMENT-ZONE-FIX`, тексты Looker Studio
  - Развилки на владельце: без изменений — `CODE-REPO-STANDUP` шаг 2b (критический путь всего
    деплоя); ответ клиента по часовому поясу (`MSKLAD-TZ-PROPOSAL`); мандат класса B на
    `AUDIT-SNAPSHOT-FIX-EMPLOYEES`/`AUDIT-COUNTERPARTIES-SNAPSHOT-RETIRE`
  - Счётчик: пары реестра 1/7 сходятся · измерено 4/7 · строк реестра на критическом пути 23 из 63 · Epic M 5/7 фаз
- Подробности для модели: **`core.fact_customer_invoices` заморожена, не «медленно растёт».**
  Единственная загрузка — один `CREATE_TABLE` (`2026-06-05 08:48:29Z`) плюс один `MERGE`
  (`2026-06-05 09:07:07Z`); в окне 90 суток (`region-asia-east1` и `region-us`,
  `INFORMATION_SCHEMA.JOBS_BY_PROJECT`) других заданий с этой целью нет вовсе. Все 4058 строк несут
  идентичный `_loaded_at`; данные документа (`moment`) обрываются на `2026-06-05` (июль/август 2026
  в таблице отсутствуют). Найдено ОДНО расписание по имени `customer_invoices`
  (`sq_marts_customer_invoices_ar`, `asia-east1`, SUCCEEDED) — оно пишет в март
  `marts.customer_invoices_ar`, читая из замороженной `core.fact_customer_invoices`, то есть
  ежедневно пересчитывает витрину поверх статичных данных; загрузчика ЯДРА для счетов не найдено.
  Контрольный запрос подтвердил: общий ETL проекта жив (почасовые задания `dim_employees` /
  `dim_counterparties` / `dim_products` от `etl-sa@…`), то есть отсутствие загрузок именно у
  `fact_customer_invoices` не является общим сбоем инфраструктуры. Полный разбор, все сырые JSON и
  команды — `reference/invoices_staleness_probe_2026-08-02.md` (самодостаточен, здесь не
  пересказывается). Предел замера, названный явно: окно `JOBS_BY_PROJECT` — 90 суток
  (`2026-05-04…2026-08-02`); заданий ДО этого окна не видно (retention BigQuery по умолчанию
  180 суток, но запрос не расширялся) — отсутствие более ранней истории не доказано, только не
  видно этим замером. Причина заморозки (отключён загрузчик / никогда не был scheduled / разовый
  ручной инструмент) — вне scope этой задачи, не устанавливалась.
- Новые открытые вопросы: не заводились этой сессией отдельным `Q`/task-ID (`ADR-091 §1`) — находка,
  требующая архитекторской адъюдикации, оформлена по прецеденту `ADR-015` файлом
  `reference/architect_review_queue_2026-08-02-2.md` (аугментирует, не заменяет реестр)
- Блокеры: нет
- updated_at: 2026-08-02
- обновил: исполнитель (сессия: INVOICES-STALENESS-PROBE)

## NEW_DECISIONS  (→ append в 06_DECISIONS_LOG.md как ADR; "нет" если нет)
- нет

## NEW_CONVENTIONS  (→ предложение правки 05; "нет" если нет)
- нет

=== END SESSION ===
