=== SESSION LOG · 2026-08-07 · SALES-DOCUMENT-OWNER-DEPLOY ===

## SESSION_LOG  (→ append в /docs, опц. CHANGELOG)
- Задача: SALES-DOCUMENT-OWNER-DEPLOY, доработка патча — внесение `document_owner_employee_id`
  в ветку `WHEN MATCHED THEN UPDATE SET` (`ADR-136 §2`)
- Сделано: в `reference/code/cf-facts/bq_ops.py`, функция `_build_merge_sql`, ветка
  `WHEN MATCHED THEN UPDATE SET` — добавлена ровно одна строка
  `T.document_owner_employee_id = S.document_owner_employee_id`. Приёмка: `git diff` (одна
  добавленная строка), `python3 -m py_compile` (OK), проверочный скрипт подтвердил, что
  различие колонок `UPDATE SET` vs `INSERT` сократилось с 6 до 5 (ровно на новую колонку,
  остаток — структурные `transaction_id`/`transaction_date`/`product_id`/`entity_type`/`agent_id`).
  Полный разбор — `reference/sales_document_owner_deploy_prep_2026-08-07.md`.
- Команды/логи ключевые: `git diff -- reference/code/cf-facts/bq_ops.py`;
  `python3 -m py_compile reference/code/cf-facts/bq_ops.py`; проверочный скрипт/лог —
  `reference/_scratch_SALES-DOCUMENT-OWNER-DEPLOY_2026-08-07/verify_columns.py` /
  `verify_columns.log`.
- Отклонения от плана: нет.

## STATE_PATCH  (→ применить к 07_STATE.md)
- Задача SALES-DOCUMENT-OWNER-DEPLOY, доработка патча: OPEN (готовность блокирует правка
  `WHEN MATCHED UPDATE SET`, `ADR-135 §4`) → DONE. Задача SALES-DOCUMENT-OWNER-DEPLOY, деплой:
  остаётся класс B, мандат НЕ выдан — этой сессией не затрагивается.
- Стенд-ап (ЗАМЕНЯЕТ блок `### Стенд-ап` в `07_STATE` целиком, НЕ дописывается, ровно пять строк):
  - Прошлый шаг: доработка патча `SALES-DOCUMENT-OWNER-DEPLOY` внесена — `document_owner_employee_id`
    добавлена в `WHEN MATCHED THEN UPDATE SET` (`ADR-136 §2`), приёмка пройдена —
    `reference/sales_document_owner_deploy_prep_2026-08-07.md`.
  - Где мы: счётчик реестра паритета 7/7; из очереди `SALES-PERIMETER-QUEUE-ADJ` (`ADR-131`)
    доработка `SALES-DOCUMENT-OWNER-DEPLOY` закрыта, деплой этой строки и
    `SALES-PERIMETER-PARITY-RECHECK` остаются открытыми.
  - Следующий шаг: `SALES-DOCUMENT-OWNER-DEPLOY, деплой` (класс B, мандат по факту готовности
    доработки — `ADR-109 §1`) параллельно с `SALES-PERIMETER-PARITY-RECHECK` (мандат выдан,
    бриф готов, не взята).
  - Развилки на владельце: выдача поимённого мандата класса B на
    `SALES-DOCUMENT-OWNER-DEPLOY, деплой`, когда владелец сочтёт нужным начать деплой.
  - Счётчик: пары реестра паритета 7/7 · Epic-1 очередь финиша — 2/4 задач очереди
    `SALES-PERIMETER-QUEUE-ADJ` остаются открытыми.
- Подробности для модели: доработка `SALES-DOCUMENT-OWNER-DEPLOY` закрыта DONE. Снапшот
  `reference/code/cf-facts/` несёт ровно один недеплоенный патч — сотрудник документа
  (`document_owner_employee_id`, теперь в обеих ветках `MERGE`). Три требования к приёмке
  будущего деплоя названы заранее `ADR-136 §4`/строкой `07_GAPS.md`: (1) `ALTER TABLE
  core.fact_sales_profit ADD COLUMN` — ДО деплоя кода; (2) настоящая доработка — уже применена
  ДО деплоя (условие выполнено); (3) первый прогон после деплоя — режим `weekly`,
  `window_days=90` (иначе июль-2026 не попадает в окно `MERGE`), окно закрывается `2026-09-29`
  (`ADR-125 §5`). Полный разбор и провенанс — `reference/sales_document_owner_deploy_prep_2026-08-07.md`.
- Новые открытые вопросы: нет.
- Блокеры: нет.
- updated_at: 2026-08-07
- обновил: executor (сессия: SALES-DOCUMENT-OWNER-DEPLOY)

## NEW_DECISIONS  (→ append в 06_DECISIONS_LOG.md; "нет" если нет)
- нет

## NEW_CONVENTIONS  (→ предложение правки 05; "нет" если нет)
- нет

=== END SESSION ===
