=== SESSION LOG · 2026-08-08 · DQ-FRESHNESS-COVERAGE-GEN ===

## SESSION_LOG  (→ append в /docs, опц. CHANGELOG)
- Задача: DQ-FRESHNESS-COVERAGE-GEN — генерация брифа задачи `DQ-FRESHNESS-COVERAGE` (подготовка)
- Сделано: прочитан обязательный контекст (`_METHOD`, `00_CHARTER`, `04_ROADMAP`, `06_INDEX`, `07_STATE`,
  `05_CONVENTIONS`, `08_TASK_BRIEF_TEMPLATE`); из `07_STATE §Мандат Claude Code` подтверждён класс A /
  параллель нет / мандат постоянный для строки «DQ-FRESHNESS-COVERAGE, подготовка»; из `07_GAPS.md` и
  `06_DECISIONS_LOG.md` (`ADR-115 §14б`, `ADR-122 §8`, `ADR-140 §последствия`) собрана полная фактура
  задачи; собран бриф `briefs/DQ-FRESHNESS-COVERAGE.md` по `08_TASK_BRIEF_TEMPLATE` с опорой на уже
  готовый образец проверок для `core.fact_customer_invoices` (`reference/invoices_loader_design_2026-08-02.md §9.2`)
  и на схемы/каденции остальных пяти таблиц (`02_ERP_CONTRACTS.md`, `reference/schema_dump_2026-07-28.md`,
  `11_INFRA_FACTS.md`, `01_ARCHITECTURE.md`)
- Команды/логи ключевые: только чтение файлов с диска, без облачных вызовов; `bash tools/session_status.sh`
  (дерево чисто), `bash tools/hooks/selftest.sh` (пройдено 36, провалено 0)
- Отклонения от плана: нет

## STATE_PATCH  (→ применить к 07_STATE.md)
- Задача DQ-FRESHNESS-COVERAGE: OPEN, бриф отсутствовал → OPEN, бриф `briefs/DQ-FRESHNESS-COVERAGE.md`
  собран (сессия `DQ-FRESHNESS-COVERAGE-GEN`, 2026-08-08), не взят
- Стенд-ап (ЗАМЕНЯЕТ блок `### Стенд-ап` в `07_STATE` целиком, НЕ дописывается, ровно пять строк):
  - Прошлый шаг: узкая форма `SALES-REFRESH-WINDOW` подготовлена текстом и провалидирована `bq query --dry_run` против живых таблиц (оба `MERGE`, ветка удаления синтаксически верна).
  - Где мы: патч готов к деплою по существу; деплой блокируется ДВУМЯ вещами — (1) отсутствием поимённого мандата класса B, (2) несвязанной незадеплоенной колонкой `document_owner_employee_id` (`SALES-DOCUMENT-OWNER-DEPLOY`), смешанной в том же файле снапшота — порядок/объединение деплоя двух патчей не решён.
  - Следующий шаг: поимённый мандат класса B на деплой узкой формы `SALES-REFRESH-WINDOW` в окне `2026-08-25`…`2026-09-29`, с явным решением порядка относительно `SALES-DOCUMENT-OWNER-DEPLOY` (владелец/архитектор); параллельно, независимо — бриф `DQ-FRESHNESS-COVERAGE` (класс A, постоянный мандат) готов и может быть взят.
  - Развилки на владельце: порядок деплоя `SALES-REFRESH-WINDOW` относительно `SALES-DOCUMENT-OWNER-DEPLOY` (объединённо одним архивом с предварительным `ALTER TABLE`, либо раздельно) — без изменений этой сессией.
  - Счётчик: пары реестра `7/7` (финиш объявлен) · очередь передачи `1/26` закрыта, блокирующих `0/9`.
- Подробности для модели: **Бриф `DQ-FRESHNESS-COVERAGE` (подготовка) собран (сессия
  `DQ-FRESHNESS-COVERAGE-GEN`, 2026-08-08), не взят.** Класс задачи — A, параллель — нет, мандат —
  постоянный (`07_STATE.md §Мандат Claude Code`, строка «DQ-FRESHNESS-COVERAGE, подготовка»); гейт
  `DQ-GATE-SCOPE-SPLIT-DEPLOY`, названный в этой же строке таблицы мандата, архивирован DONE и снят
  фактом (`ADR-140 §последствия`) — сессии-исполнителю опираться на актуальный `07_GAPS.md`
  (строка `DQ-FRESHNESS-COVERAGE`: «нет — гейт архивирован DONE; гейт снят фактом»), а не на устаревшую
  формулировку колонки «Основание» таблицы мандата, которая эту сессию не правила (правка этой колонки
  не входила в её «Файлы на запись», расхождение только называется здесь). Бриф ставит задачу
  спроектировать проверки свежести (техническую по `_loaded_at` + бизнес-диагностическую по бизнес-дате,
  без деплоя) для шести таблиц `core.fact_returns`/`fact_purchases`/`fact_inventory`/`fact_payments`/
  `fact_customer_invoices`/`fact_commissionreportin`, из которых `fact_customer_invoices` уже полностью
  спроектирована другой задачей (`reference/invoices_loader_design_2026-08-02.md §9.2`, порог `48ч`) и
  переносится без переделки; для остальных пяти порог технической проверки выводится по уже принятой
  формуле «`2 × период каденции`» (`03_PIPELINE_SPEC.md:86`) из фактов каденции `11_INFRA_FACTS.md`/
  `01_ARCHITECTURE.md`: часовая (`fact_purchases`, `step_purchases` NON-BLOCKING в `msklad-pipeline-hourly`)
  → `2ч`; суточная (`fact_inventory`, `fact_payments`, `fact_commissionreportin`) → `48ч`; недельная
  (`fact_returns`, только в `msklad-pipeline-weekly`) → `336ч`. Бриф явно требует от исполнителя ПЕРЕД
  написанием проверки (A) для каждой из пяти новых таблиц подтвердить чтением кода загрузчика инвариант
  «один стамп `_loaded_at` на прогон» (аналог `§6.4` того же артефакта) — не подставлять правдоподобное,
  если не подтвердится. Деплой и подключение к списку `CHECKS`/`workflow.yaml` — вне scope, отдельная
  строка мандата «DQ-FRESHNESS-COVERAGE, деплой» (класс B, мандат не выдан).
- Новые открытые вопросы: нет
- Блокеры: нет
- updated_at: 2026-08-08
- обновил: generator (сессия: DQ-FRESHNESS-COVERAGE-GEN)

## NEW_DECISIONS  (→ append в 06_DECISIONS_LOG.md как ADR; "нет" если нет)
- нет

## NEW_CONVENTIONS  (→ предложение правки 05; "нет" если нет)
- нет

=== END SESSION ===
