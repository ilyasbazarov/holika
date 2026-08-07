# TASK BRIEF · SALES-DOCUMENT-OWNER-INGEST

**Класс задачи (ADR-076):** A
<Чтение репо; запись только в снапшот `reference/code/cf-facts/` и в `/reference`, коммит без push.
Ничего не деплоит, ни одного живого `GET` к МойСкладу — состав поля уже подтверждён офлайн
(`reference/sales_employee_attribution_2026-08-07.md §3`, чтение сохранённого тела
`reference/_scratch_PARITY-CHECK-SALES-RETURNS_2026-08-01/demand_page_0.json`). Совпадает с
`07_STATE.md` §«Мандат Claude Code: класс задач», строка `SALES-DOCUMENT-OWNER-INGEST`.>

**Параллель (ADR-082 §1, уточнён `ADR-083 §1`):** да
<Совпадает с колонкой «Параллель» той же строки таблицы `07_STATE`. Перед фактическим
одновременным запуском с другой задачей — обязателен `bash tools/parallel_check.sh
SALES-DOCUMENT-OWNER-INGEST <TASK2>`.>

**Файлы на запись** (полный список):
- `reference/code/cf-facts/` — правка снапшота: `fetch_demands.py` (парсинг `owner.meta.href`),
  `bq_ops.py` (новая колонка в `STAGING_SCHEMA` и в MERGE `core.fact_sales_profit`),
  `reference/code/cf-facts/MANIFEST.md` (провенанс/sha256 патча, если каталог его ведёт)
- `reference/sales_document_owner_ingest_<date>.md` — итоговый отчёт сессии: состав диффа,
  открытый техвопрос по версионированию `owner`, ссылка на провенанс
- `reference/_scratch_SALES-DOCUMENT-OWNER-INGEST_<date>/` — рабочие файлы сессии (`ADR-076 §6`)

---

## Роль
Ты — исполнитель проекта. Законы — `CLAUDE.md`, стандарты — `05_CONVENTIONS.md` Части I и II.
Модель исполнения: ты исполняешь сам (`ADR-082 §2`). Эта задача не содержит не-идемпотентных
шагов (никакого `deploy`/`run`/`update`/прод-`bq query`/`git push` в её составе нет — деплой
патча заведён ОТДЕЛЬНОЙ будущей задачей и в scope не входит). `Done` — только по проверяемому
диффу и логу чтения, не по «должно работать». Работаешь в СВОЁМ рабочем дереве и коммитишь в
СВОЮ ветку (`ADR-081 §6`). `07_STATE`, `06_DECISIONS_LOG` и `06_INDEX` не правишь: session-блок
кладёшь файлом в `reference/_inbox/`.

## Цель
Добавить в снапшот `cf-facts` поле сотрудника-владельца ДОКУМЕНТА `entity/demand`
(`owner.meta.href`) как новую колонку `document_owner_employee_id`, по образцу уже читаемого
поля `agent_id`/`agent.meta.href` — от парсинга в `fetch_demands.py` до колонки в staging-схеме
и `MERGE` в `core.fact_sales_profit` (`bq_ops.py`). Патч ТОЛЬКО пишется в снапшот, никуда не
деплоится и не исполняется этой сессией.

## Context-to-load (обязательно прочитать перед работой)
- `_METHOD.md`, `00_CHARTER.md`, `05_CONVENTIONS.md`, `07_STATE.md` (всегда, с диска по именам)
- `02_ERP_CONTRACTS.md` — секции схем `core.fact_sales_profit` (колонка `agent_id`) и
  `dim_counterparties`/`owner_employee_id` — для понимания существующего паттерна FK-полей и
  формы записи новой колонки в контракт (сама правка контракта — вне scope этой сессии, см. ниже)
- `reference/sales_employee_attribution_2026-08-07.md` §3 «Что нужно добавить в загрузчик» —
  полная фактура правки, состав поля, обоснование, открытый техвопрос о версионировании `owner`
- `reference/sales_ingest_patch_2026-08-03.md` §1 — прецедент того же класса правки (`agent_id`),
  на который прямо ссылается фактура выше
- `reference/code/cf-facts/fetch_demands.py` — текущий парсинг `agent_href`/`agent_id`
  (строки ~91–94, ~107–108, ~143–160) — паттерн для повторения на `owner`
- `reference/code/cf-facts/bq_ops.py` — `STAGING_SCHEMA` (строки ~47–65) и `_build_merge_sql`
  (строки ~230–352: `USING (...)`, `WHEN MATCHED THEN UPDATE SET`, `WHEN NOT MATCHED THEN
  INSERT (...) VALUES (...)`) — три места правки
- `reference/code/cf-facts/MANIFEST.md` — если каталог ведёт провенанс патчей текстом/sha256,
  формат записи бери оттуда
Если чего-то из списка нет в контексте → выдай `CONTEXT GAP` и остановись.

## Входы
- Снапшот `reference/code/cf-facts/` (текущее состояние — читать с диска на момент старта
  сессии, `updateTime` ревизии не предполагать неизменным, `07_STATE.md`).
- Подтверждённая форма поля источника: `entity/demand` несёт `owner.meta.href`, формат идентичен
  `agent.meta.href` (сырое тело — `reference/_scratch_PARITY-CHECK-SALES-RETURNS_2026-08-01/
  demand_page_0.json`, ключ `owner.meta.href`).
- Существующий паттерн `agent_id` в `fetch_demands.py`/`bq_ops.py` как образец диффа (не
  придумывать новую форму).

## Шаги
1. В `fetch_demands.py`: рядом с извлечением `agent_href`/`agent_id` (строки ~91–94) добавить
   аналогичное извлечение `owner_href = demand.get("owner", {}).get("meta", {}).get("href", "")`
   и `document_owner_employee_id = parse_href(owner_href)`. Поле — уровня ДОКУМЕНТА, проставляется
   на каждую позицию документа при разворачивании в построчный вид (как сейчас `agent_id`, строка
   ~149). Добавить `document_owner_employee_id` в словарь `all_records.append({...})`. Логировать
   отсутствие (`if not document_owner_employee_id: log.warning(...)`) по аналогии со строкой
   ~107–108 для `agent_id` — не молчать при `NULL`.
2. В `bq_ops.py`: добавить `bigquery.SchemaField("document_owner_employee_id", "STRING")` в
   `STAGING_SCHEMA` рядом с `agent_id`. В `_build_merge_sql`: добавить `s.document_owner_employee_id`
   в `SELECT` внутри `USING (...)`, добавить колонку в `WHEN NOT MATCHED THEN INSERT (columns)` и
   в соответствующий `VALUES (...)` — явный список колонок (`C1`, `ADR-030`, `MERGE … WHEN NOT
   MATCHED THEN INSERT ROW` запрещён). **Решение по `WHEN MATCHED THEN UPDATE SET`:** текущий код
   НЕ обновляет `agent_id` при совпадении (строки ~294–310) — только количественные/денежные
   поля. Повторить то же для `document_owner_employee_id` (не добавлять в `UPDATE SET`), чтобы
   новая колонка была консистентна с уже принятым поведением `agent_id`, а не изобретала своё.
   Если при чтении кода обнаружится, что это решение спорно (например, отдельное намерение
   разработчика) — не молчать, назвать явно в отчёте, не менять поведение самовольно.
3. Проверить итоговый дифф на соответствие `C1` (`ADR-030`) и на отсутствие правок вне
   заявленных файлов — в частности НЕ трогать `reference/sql/sq_marts_sales_overview.sql`
   (явно вне scope).
4. Если `reference/code/cf-facts/MANIFEST.md` ведёт провенанс патчей (sha256/дата) — обновить
   его записью по этому патчу, тем же форматом, что уже используется для прежних правок.
5. Зафиксировать открытый техвопрос из фактуры (§3 источника: версионируется ли `owner` документа
   отдельно от самого документа, как `dim_counterparties` через SCD2) в
   `reference/sales_document_owner_ingest_<date>.md` как явный нерешённый пункт — не пытаться
   ответить на него замером или обращением к API-документации (вне мандата класса A этой задачи,
   живой замер — класс B).
6. Написать `reference/sales_document_owner_ingest_<date>.md`: состав диффа файл-за-файлом, что
   НЕ было сделано (деплой, правка `02_ERP_CONTRACTS.md`, правка витрины), провенанс источника
   поля, открытый техвопрос по версионированию.

## Критерии приёмки (Acceptance)
- `fetch_demands.py` извлекает `document_owner_employee_id` из `owner.meta.href` тем же приёмом,
  что и `agent_id` из `agent.meta.href`, и проставляет его на каждую позицию документа.
- `bq_ops.py`: колонка присутствует в `STAGING_SCHEMA`; в `_build_merge_sql` колонка есть в
  `SELECT` внутри `USING`, в явном списке `INSERT (колонки)` и в соответствующем `VALUES` — без
  `MERGE ... INSERT ROW` (проверяемо чтением диффа на соответствие `C1`).
- Никаких правок `02_ERP_CONTRACTS.md`, `sq_marts_sales_overview.sql`, live-конфигураций,
  деплой-скриптов в диффе нет.
- `reference/sales_document_owner_ingest_<date>.md` создан, содержит явный нерешённый техвопрос
  о версионировании `owner`, не пытается его закрыть.
- Session-блок в `reference/_inbox/` присутствует.

## Что вернуть человеку (Return-this)
- Дифф трёх файлов (`fetch_demands.py`, `bq_ops.py`, при наличии — `MANIFEST.md`) в
  `reference/code/cf-facts/` — точные пути, что изменено построчно.
- `reference/sales_document_owner_ingest_<date>.md` — отчёт сессии.
- Пояснение владельцу (обычными словами): что добавлено, что осталось нерешённым (версионирование
  `owner`), что деплой и правка контракта/витрины — отдельные будущие шаги, требующие отдельного
  мандата/ADR.

## Вне scope этой задачи
- Деплой патча `cf-facts` — отдельная будущая задача, заводится по факту готовности этого патча
  (класс B, требует ADR).
- Правка `02_ERP_CONTRACTS.md` (документирование новой колонки контрактом) — отдельным ADR при
  принятии решения, не этой сессией.
- Правка `reference/sql/sq_marts_sales_overview.sql` — явно вне scope до появления поля в `core`
  (решение владельца после деплоя).
- Живой `GET` к МойСкладу для проверки, версионируется ли `owner` отдельно от документа —
  класс B, не эта сессия; техвопрос фиксируется как открытый, не закрывается.
- Закрытие строки `Q-78` целиком — эта задача даёт только правку загрузчика; окончательное
  закрытие зависит от деплоя и последующего решения по витрине.

## В конце сессии
Выдай SESSION-блок по формату `05_CONVENTIONS.md` Часть III
(`SESSION_LOG` / `STATE_PATCH` / `NEW_DECISIONS` / `NEW_CONVENTIONS`), файлом в
`reference/_inbox/session_SALES-DOCUMENT-OWNER-INGEST_<date>.md`.
