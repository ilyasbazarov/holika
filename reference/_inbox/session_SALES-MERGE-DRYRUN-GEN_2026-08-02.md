=== SESSION LOG · 2026-08-02 · SALES-MERGE-DRYRUN-GEN ===

## SESSION_LOG  (→ append в /docs, опц. CHANGELOG)
- Задача: SALES-MERGE-DRYRUN-GEN — генерация брифа задачи `SALES-MERGE-DRYRUN` (класс A): снятие двух
  технических неизвестных патча продаж (`SALES-REFRESH-WINDOW`) — допустим ли `UPDATE` партиционирующей
  колонки `transaction_date` внутри `MERGE` (проверяется `bq query --dry_run`), и назван ли в коде
  источник COGS для диапазона выборки шире 7/90 суток (проверяется чтением `fetch_byvariant.py`)
- Сделано: прочитан обязательный контекст (`_GENERATOR.md`, `_METHOD.md`, `00_CHARTER.md`,
  `07_STATE.md`, `08_TASK_BRIEF_TEMPLATE.md`); проверка `ADR-054` по каждому файлу — совпало; класс (A),
  параллель (да), мандат (постоянный) взяты дословно из `07_STATE.md:354` (таблица мандата) и
  `07_STATE.md:472` (GAP-реестр), расхождения между двумя строками не было; постановка задачи
  дополнительно сверена с `reference/parity_coarse_adj_2026-08-02.md §4` (~строка 115), текст совпадает
  дословно с формулировкой GAP-реестра; прочитан снапшот `reference/code/cf-facts/bq_ops.py`
  (`_build_merge_sql`, `promote_to_core`, `PARTITION BY transaction_date`) и `fetch_byvariant.py`
  целиком — найден и в бриф внесён точный адрес `WHEN MATCHED THEN UPDATE SET` (15 колонок,
  `transaction_date` среди них нет), точная сигнатура `fetch_byvariant_cogs(token, date_from, date_to,
  session)`, и точная строка выбора источника COGS `if window_days >= 90:` (`bq_ops.py` ~строка 331);
  бриф положен в `briefs/SALES-MERGE-DRYRUN.md`
- Команды/логи ключевые: только чтение с диска (обязательный контекст, `06_INDEX.md`,
  `reference/parity_coarse_adj_2026-08-02.md`, `briefs/SALES-REFRESH-WINDOW.md`,
  `reference/code/cf-facts/bq_ops.py`, `fetch_byvariant.py`, `config.py`, `02_ERP_CONTRACTS.md`); живых
  команд к облаку/МойСкладу не исполнялось (роль генератора не читает секреты, исполняющий `bq
  --dry_run` — предмет самого брифа, не этой сессии)
- Отклонения от плана: нет — бриф собран прецедентно по строке GAP-реестра и строке мандата, обе уже
  дают полную постановку задачи (`ADR-109 §4`), новой архитекторской адъюдикации не требовалось. Бриф
  явно разделяет вопрос (а) — dry-run как СИНТАКСИЧЕСКУЮ проверку — от гарантии успешного runtime-
  исполнения, чтобы исполнитель не выдал dry-run-успех за окончательное «да» без оговорки.

## STATE_PATCH  (→ применить к 07_STATE.md)
- Задача SALES-MERGE-DRYRUN: READY → READY, бриф готов к исполнению (`briefs/SALES-MERGE-DRYRUN.md`),
  не взят
- Стенд-ап (ЗАМЕНЯЕТ блок `### Стенд-ап` в `07_STATE` целиком, НЕ дописывается, ровно пять строк):
  - Прошлый шаг: бриф `SALES-MERGE-DRYRUN` (класс A) собран (`briefs/SALES-MERGE-DRYRUN.md`) — снятие
    двух технических неизвестных патча продаж (допустимость `UPDATE transaction_date` внутри `MERGE`;
    источник COGS шире 7/90 суток), готов к исполнению отдельной сессией, не исполнен
  - Где мы: восстановление потока данных остаётся приоритетом перед сверкой паритета «на сейчас»
    (`FACTS-WORKFLOW-STOP-DIAG`, `ADR-111`) — решение владельца о форме восстановления не получено;
    параллельно без изменений готовы к исполнению брифы `SALES-MERGE-DRYRUN` и `SALES-REFRESH-WINDOW`
    (подготовка); исторические майские измерения паритета в силе
  - Следующий шаг: решение владельца о форме восстановления загрузки (снять блокировку конкретного
    прогона, либо править `drift_check`/порог в `cf-dq`, либо подтвердить падение выручки как реальное),
    затем `FACTS-BACKFILL` (класс B), затем `DQ-SOURCE-CAPTURE`; параллельно без изменений —
    `DIM-METADATA-MAPPINGS-FROZEN`, `MARTS-BUILD-STAMP`, `FACT-SALES-BYVARIANT-BACKUP-OWNER`,
    `SALES-CONSIGNMENT-REVENUE`, `SALES-PERIMETER-EXTEND`, `SALES-REFRESH-WINDOW`, `SALES-MERGE-DRYRUN`
    (бриф готов, не взят), `FX-MAY-WINDOW-D1-TAIL`, `INGEST-CURRENCY-ASSERT` шаги 1-2, подготовка
    `INGEST-MOMENT-ZONE-FIX`, тексты Looker Studio
  - Развилки на владельце: решение о форме восстановления загрузки (см. «Следующий шаг»); первый `push`
    код-репо в `holika-prod`; ответ клиента по часовому поясу (`MSKLAD-TZ-PROPOSAL`); мандат класса B на
    `AUDIT-SNAPSHOT-FIX-EMPLOYEES`/`AUDIT-COUNTERPARTIES-SNAPSHOT-RETIRE`; выбор варианта патча
    `SALES-REFRESH-WINDOW` — после исполнения готового брифа `SALES-MERGE-DRYRUN`
  - Счётчик: пары реестра 2/7 сходятся · таблиц живых 15 из 26 (до восстановления, не переизмерялось) ·
    строк реестра на критическом пути 23 из 63 · Epic M 5/7 фаз
- Новые открытые вопросы: нет
- Блокеры: нет
- updated_at: 2026-08-02
- обновил: generator (сессия: SALES-MERGE-DRYRUN-GEN)

## NEW_DECISIONS  (→ append в 06_DECISIONS_LOG.md; "нет" если нет)
- нет

## NEW_CONVENTIONS  (→ предложение правки 05; "нет" если нет)
- нет

=== END SESSION ===
