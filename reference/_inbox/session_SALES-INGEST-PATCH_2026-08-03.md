=== SESSION LOG · 2026-08-03 · SALES-INGEST-PATCH ===

## SESSION_LOG
- Задача: SALES-INGEST-PATCH — подготовка (класс A) текста патча периметра ингеста продаж
  (`entity/retaildemand` + продажи `entity/commissionreportin`) и признания выручки
  (исключение отгрузок комиссионерам), закрывающего строки `SALES-PERIMETER-EXTEND` и
  `SALES-CONSIGNMENT-REVENUE` в части подготовки.
- Сделано:
  - Шаг 1: различитель формы фикса установлен — `agent_id` (уже загружаемое поле), список
    трёх контрагентов исчерпывающе измерен `ADR-104 §2/§5`. Не `CONTEXT GAP`.
  - Шаг 2: новый файл `reference/code/cf-facts/fetch_perimeter.py`
    (`fetch_retaildemand_positions`, `fetch_commission_sales_positions`); `config.py`
    (`STG_FACT_SALES_PERIMETER`, `PERIMETER_WINDOW_DAYS`, `COMMISSION_CHANNEL_AGENT_IDS`);
    `bq_ops.py` (`PERIMETER_STAGING_SCHEMA`, `ensure_perimeter_staging_table`,
    `load_perimeter_staging`, `_build_perimeter_merge_sql`, `promote_perimeter_to_core` —
    отдельные от существующего `_build_merge_sql`); `main.py` (режимы `perimeter`,
    `perimeter_promote`).
  - Шаг 3: `fetch_demands.py` — исключение позиций с `agent_id` из списка комиссионного
    канала, с логированием количества/суммы исключённого.
  - Шаг 4: `reference/parity_registry.md` строки 18–19 — правило-мост (объект паритета
    продаж = вариант (a), формула приведения нашей величины, пометка «патч подготовлен, не
    задеплоен»).
  - Шаг 5: обе формулы (до/после патча) и ожидаемый сдвиг по маю-2026 выписаны числом ДО
    прогона — `reference/sales_ingest_patch_2026-08-03.md §5`.
  - Артефакт `reference/sales_ingest_patch_2026-08-03.md`: вердикт, обе формулы, полный
    `git diff` снапшота, приёмочные проверки.
- Команды/логи ключевые: `python3 -m py_compile` (5 файлов снапшота, без ошибок, read-only,
  без сети) — `reference/_scratch_SALES-INGEST-PATCH_2026-08-03/py_compile.log`; `git diff`
  снапшота — `reference/_scratch_SALES-INGEST-PATCH_2026-08-03/cf_facts_diff.txt`; `grep -n
  "INSERT ROW"`/`"THEN INSERT ROW"` — `reference/sales_ingest_patch_2026-08-03.md §6`.
- Отклонения от плана: первый греп-запрос приёмки («нет INSERT ROW») дал 1 ложноположительное
  совпадение (комментарий, не SQL) — пойман до публикации вердикта, уточнён вторым запросом
  (`ADR-044`), исправлено в артефакте до сдачи.

## STATE_PATCH
- Задача SALES-PERIMETER-EXTEND: READY (подготовка) → подготовка DONE, деплой — класс B,
  гейтится `ADR-065`, ждёт `DEPLOY-PROCEDURE`.
- Задача SALES-CONSIGNMENT-REVENUE: READY (подготовка) → подготовка DONE, деплой — класс B,
  гейтится `ADR-065`, ждёт `DEPLOY-PROCEDURE`.
- Стенд-ап (ЗАМЕНЯЕТ блок `### Стенд-ап` в `07_STATE` целиком, ровно пять строк):
  - Прошлый шаг: `SALES-INGEST-PATCH` закрыта DONE в части подготовки — текст патча периметра
    и признания выручки готов против снапшота `cf-facts`, не задеплоен; артефакт
    `reference/sales_ingest_patch_2026-08-03.md`.
  - Где мы: обе строки `SALES-PERIMETER-EXTEND`/`SALES-CONSIGNMENT-REVENUE` разгейчены до
    состояния «готово к деплою»; деплой — класс B через `DEPLOY-PROCEDURE`, вместе с уже
    готовым `SALES-REFRESH-WINDOW`.
  - Следующий шаг: деплой `cf-facts` (класс B, `DEPLOY-PROCEDURE`, `ADR-115`) — объединяющий
    оба готовых патча (этот плюс `SALES-REFRESH-WINDOW`) в одну ревизию, владелец решает
    порядок/объединение; `INVOICES-BACKFILL`/`INVOICES-PARITY-RECHECK`/
    `DQ-GATE-RECOVERY-CONFIRM` — параллельно, не эта сессия.
  - Развилки на владельце: объединять ли деплой `SALES-INGEST-PATCH` и `SALES-REFRESH-WINDOW`
    в одну ревизию `cf-facts` или разносить по времени — не решено этой сессией.
  - Счётчик: пары реестра 2/7 сходятся (без изменений этой сессией — задача техническая,
    не паритетная сверка) · измерено 7/7 · Epic M 6/7 фаз.
- Подробности для модели: Патч `SALES-INGEST-PATCH` готов текстом (снапшот `cf-facts`, не
  задеплоен). Ключевое для следующей сессии: ОБА готовых патча (`SALES-REFRESH-WINDOW` и
  этот) правят один и тот же CF (`cf-facts`), но независимые части кода (`_build_merge_sql`
  vs новый `_build_perimeter_merge_sql`/новая staging-таблица) — конфликта на уровне текста
  нет, но деплой обоих в одну ревизию или раздельно решает владелец при постановке
  `DEPLOY-PROCEDURE`. После деплоя ТОЛЬКО этого патча (без `SALES-REFRESH-WINDOW`) ожидаемое
  расхождение по маю ВРЕМЕННО ухудшится с `0,31 %` до `≈1,75 %` (риск R1, `ADR-101`) — не
  принимать за регресс, это уже посчитано и записано (`reference/sales_ingest_patch_2026-08-03.md §5`).
  Перед деплоем обязательна одна проверка класса B: живой `GET` одной позиции
  `entity/retaildemand`, чтобы подтвердить состав полей позиции (предположен по аналогии с
  `entity/demand`, не измерен для retaildemand). Список
  `config.py::COMMISSION_CHANNEL_AGENT_IDS` — измеренный факт на зону до 2026-08-01, не
  структурный признак; новый комиссионер потребует повторного замера.
- Новые открытые вопросы: нет.
- Блокеры: нет.
- updated_at: 2026-08-03
- обновил: исполнитель (сессия: SALES-INGEST-PATCH)

## NEW_DECISIONS
нет

## NEW_CONVENTIONS
нет

=== END SESSION ===
