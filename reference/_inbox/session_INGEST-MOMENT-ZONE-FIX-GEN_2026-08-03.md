=== SESSION LOG · 2026-08-03 · INGEST-MOMENT-ZONE-FIX-GEN ===

## SESSION_LOG
- Задача: INGEST-MOMENT-ZONE-FIX-GEN — сборка брифа подготовки патча для `INGEST-MOMENT-ZONE-FIX`
  (задание владельца прямой репликой в чате, не по стенд-апу; `07_STATE.md:518` — строка мандата
  уже существовала, ADR не заводится).
- Сделано:
  - Прочитан обязательный контекст (`_METHOD`, `00_CHARTER`, `04_ROADMAP`, `06_INDEX`, `07_STATE`,
    `05_CONVENTIONS`) + `08_TASK_BRIEF_TEMPLATE`; точечно `ADR-088` (полный текст), `ADR-101 §6`.
  - Найдена и подтверждена чтением кода неточность формулировки `ADR-088 §4`: «списания и комиссии
    в `cf-finance`» — фактически CF называется `cf-loss-commission` (`11_INFRA_FACTS.md:26`), и его
    ингест дефекта не содержит (`moment` хранится как `TIMESTAMP` без обрезки). Настоящий дефект
    для этих двух веток — `reference/sql/sq_marts_expenses.sql:20,44`
    (`CAST(moment AS DATE)` вместо `DATE(moment, 'Asia/Bishkek')`).
  - Собран бриф `briefs/INGEST-MOMENT-ZONE-FIX.md`: три файла на патч (`fetch_returns.py`,
    `fetch_purchases.py`, `sq_marts_expenses.sql`), явно выведены из scope окно API-запроса (`Q-93`)
    и `core.fact_payments.moment` (правило не установлено, `ADR-088 §4`).
- Команды/логи ключевые: только чтение файлов (`Read`/`grep`/`ls`), без облачных вызовов.
- Отклонения от плана: нет.

## STATE_PATCH
- Задача `INGEST-MOMENT-ZONE-FIX, подготовка патча`: READY (бриф не был готов) → READY (бриф готов,
  не взят).
- Стенд-ап (ЗАМЕНЯЕТ блок `### Стенд-ап` в `07_STATE` целиком, ровно пять строк):
  - Прошлый шаг: бриф `INGEST-MOMENT-ZONE-FIX` (подготовка патча) собран; `SALES-INGEST-PATCH`
    (подготовка) остаётся закрытой DONE предыдущей сессией, не взята в деплой.
  - Где мы: три готовых, но не задеплоенных патча `cf-facts`/`cf-loss-commission`-слоя
    (`SALES-INGEST-PATCH`, `SALES-REFRESH-WINDOW`, теперь и `INGEST-MOMENT-ZONE-FIX`) копятся к
    одному владельческому решению об объединении ревизий через `DEPLOY-PROCEDURE`.
  - Следующий шаг: исполнение брифа `INGEST-MOMENT-ZONE-FIX` (класс A, подготовка, параллель нет) —
    свободно; деплой всех накопленных патчей `cf-facts`/`cf-finance` (класс B, `DEPLOY-PROCEDURE`,
    `ADR-115`) — решение владельца по составу и порядку ревизий, не эта сессия.
  - Развилки на владельце: объединять ли деплой `SALES-INGEST-PATCH`/`SALES-REFRESH-WINDOW`/
    `INGEST-MOMENT-ZONE-FIX` в одну ревизию `cf-facts` (плюс отдельно `sq_marts_expenses`) или
    разносить по времени — не решено этой сессией.
  - Счётчик: пары реестра 2/7 (без изменений) · измерено 7/7 · Epic M 6/7 фаз.
- Подробности для модели: **Уточнение локализации дефекта `ADR-088 §4` для «списания/комиссии»
  (сессия `INGEST-MOMENT-ZONE-FIX-GEN`, 2026-08-03).** `ADR-088 §4` называет несущий дефект CF
  `cf-finance`; живой снапшот этого не подтверждает — CF называется `cf-loss-commission`
  (`11_INFRA_FACTS.md:26`), его ингест хранит `moment` как `TIMESTAMP` без обрезки
  (`LOSS_SCHEMA`/`COMM_SCHEMA`), дефекта там нет. Настоящий дефект (UTC объявлен местным) сидит в
  scheduled-query марта расходов — `reference/sql/sq_marts_expenses.sql:20,44`
  (`CAST(l.moment AS DATE)` / `CAST(c.moment AS DATE)`). `06` не правится (append-only, текст
  `ADR-088` не редактируется), уточнение и полный разбор — в брифе `briefs/INGEST-MOMENT-ZONE-FIX.md`
  §Входы·2 и в `NEW_DECISIONS` этого блока. Следующая сессия (исполнитель брифа) обязана патчить
  `reference/sql/sq_marts_expenses.sql`, а не искать дефект внутри `cf-finance`/`cf-loss-commission`.
- Новые открытые вопросы: нет.
- Блокеры: нет.
- updated_at: 2026-08-03
- обновил: generator (сессия: INGEST-MOMENT-ZONE-FIX-GEN)

## NEW_DECISIONS
нет (уточнение локализации — факт из чтения кода в рамках уже принятого `ADR-088 §4`, не новое
архитектурное решение; `06` append-only, старый текст не редактируется).

## NEW_CONVENTIONS
нет.

=== END SESSION ===
