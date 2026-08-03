=== SESSION LOG · 2026-08-03 · INVOICES-PARITY-RECHECK-GEN ===

## SESSION_LOG
- Задача: INVOICES-PARITY-RECHECK-GEN — генерация брифа для `INVOICES-PARITY-RECHECK`
- Сделано:
  - собран бриф `briefs/INVOICES-PARITY-RECHECK.md` по `08_TASK_BRIEF_TEMPLATE.md`
  - класс задачи (B) и признак параллелимости (нет) взяты из `07_STATE.md §Мандат Claude Code`
    строка `INVOICES-PARITY-RECHECK` (`07_STATE.md:554`) — расхождения с шапкой брифа нет
  - в шапку брифа внесены ДВА независимых гейта: (1) мандат класса B на саму задачу не выдан
    (`_GENERATOR.md §4a`); (2) предметная зависимость от `INVOICES-BACKFILL` (`T5` программы
    `INVOICES-PROGRAMME`, `ADR-110 §3`), которая сама открыта и ждёт своего мандата — досев ещё
    не исполнен, поэтому повторная сверка сейчас не имеет предмета
  - «Файлы на запись» заполнены маркированным списком (`reference/parity_registry.md`,
    `reference/invoices_parity_recheck_<date>.md`, `reference/_scratch_INVOICES-PARITY-RECHECK_<date>/`)
- Команды/логи ключевые: `bash tools/session_status.sh` (СТАРТ — чисто, RC 0);
  `bash tools/hooks/selftest.sh` (пройдено 36, провалено 0)
- Отклонения от плана: нет

## STATE_PATCH
- Задача INVOICES-PARITY-RECHECK: OPEN (без изменения статуса) — бриф собран, задача остаётся
  заблокированной двумя независимыми гейтами (мандат класса B не выдан; `INVOICES-BACKFILL` не
  завершена)
- Стенд-ап:
  - Прошлый шаг: собран бриф `briefs/INVOICES-PARITY-RECHECK.md` (генерация, не исполнение) — задача
    остаётся заблокированной до мандата класса B и до завершения `INVOICES-BACKFILL`.
  - Где мы: программа `INVOICES-PROGRAMME` (`ADR-110`) дошла до готового брифа на последнем шаге
    (`T6`); шаг `T5` (`INVOICES-BACKFILL`) ещё не исполнен, мандата на неё тоже нет.
  - Следующий шаг: деплой `cf-facts` (класс B, `DEPLOY-PROCEDURE`, `ADR-115`), объединяющий
    `SALES-INGEST-PATCH` и `SALES-REFRESH-WINDOW`; параллельно — `INVOICES-BACKFILL`
    (мандат класса B нужен раньше этой задачи), `DQ-GATE-RECOVERY-CONFIRM`.
  - Развилки на владельце: объединять ли деплой `SALES-INGEST-PATCH` и `SALES-REFRESH-WINDOW` в
    одну ревизию `cf-facts` или разносить по времени — не решено; выдавать ли поимённый мандат
    класса B на `INVOICES-BACKFILL` (предшествует мандату на эту задачу).
  - Счётчик: пары реестра 2/7 сходятся (без изменений этой сессией) · измерено 7/7 · Epic M 6/7 фаз.
- Подробности для модели: без изменений этой сессией (генерация брифа не производила замеров и не
  меняла фактов проекта); бриф `briefs/INVOICES-PARITY-RECHECK.md` самодостаточен для следующей
  сессии, дублировать его содержимое здесь не требуется.
- Новые открытые вопросы: нет
- Блокеры: мандат класса B на `INVOICES-PARITY-RECHECK` не выдан; `INVOICES-BACKFILL` (гейт из
  GAP-реестра) не завершена
- updated_at: 2026-08-03
- обновил: generator (сессия: INVOICES-PARITY-RECHECK-GEN)

## NEW_DECISIONS
нет

## NEW_CONVENTIONS
нет

=== END SESSION ===
