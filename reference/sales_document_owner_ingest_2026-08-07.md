# FILE: sales_document_owner_ingest_2026-08-07.md

# `SALES-DOCUMENT-OWNER-INGEST` — правка снапшота `cf-facts`: сотрудник-владелец документа

**Дата:** 2026-08-07 (Бишкек) · **Класс задачи:** A (правка снапшота `reference/code/cf-facts/`,
ничего не деплоит, ни одного живого `GET` к МойСкладу, в `core.*`/`marts.*` не пишет) · **Роль:**
исполнитель · **Дерево/ветка:** `worktrees/SALES-DOCUMENT-OWNER-INGEST` / `s/SALES-DOCUMENT-OWNER-INGEST`.
**Бриф:** `briefs/SALES-DOCUMENT-OWNER-INGEST.md`.
**Скрипты и рабочие файлы:** `reference/_scratch_SALES-DOCUMENT-OWNER-INGEST_2026-08-07/`.

---

## Что сделано

Патч добавляет колонку `document_owner_employee_id` — сотрудник-владелец ДОКУМЕНТА `entity/demand`
(поле `owner.meta.href`), тем же приёмом, что уже читается `agent_id` из `agent.meta.href`. Патч
только пишется в снапшот `reference/code/cf-facts/`, никуда не деплоится и не исполняется.

### `reference/code/cf-facts/fetch_demands.py`

- Рядом с извлечением `agent_href`/`agent_id` (строка ~91) добавлено:
  `owner_href = demand.get("owner", {}).get("meta", {}).get("href", "")` и
  `document_owner_employee_id = parse_href(owner_href)`.
- Добавлено логирование отсутствия поля по аналогии с `agent_id`:
  `if not document_owner_employee_id: log.warning(...)`.
- Поле проставлено на каждую позицию документа в словаре `all_records.append({...})` — то есть
  поле уровня ДОКУМЕНТА размножается на строки построчного вида, как и `agent_id`.

### `reference/code/cf-facts/bq_ops.py`

- `STAGING_SCHEMA`: добавлено `bigquery.SchemaField("document_owner_employee_id", "STRING")` рядом
  с `agent_id`.
- `_build_merge_sql` (основной `MERGE` в `core.fact_sales_profit` по `entity/demand`):
  - `s.document_owner_employee_id` добавлен в `SELECT` внутри `USING (...)`;
  - колонка добавлена в явный список `WHEN NOT MATCHED THEN INSERT (колонки)` и в
    соответствующий `VALUES (...)` — `INSERT ROW` не используется (`C1`, `ADR-030`).
  - **`WHEN MATCHED THEN UPDATE SET` — колонка НЕ добавлена.** Решение повторяет уже принятое
    поведение `agent_id`: текущий код не обновляет `agent_id` при совпадении строки, только
    количественные/денежные поля и разрезы (`sales_channel_*`, `project_*`, `discount`,
    `_loaded_at`). Спорности при чтении кода не обнаружено — `agent_id` и
    `document_owner_employee_id` оба FK-поля на документ одной природы, и оба сегодня
    трактуются одинаково (не апдейтятся). Отдельное намерение разработчика на этот счёт в коде
    не найдено.
- **`_build_perimeter_merge_sql` (отдельный `MERGE` для периметра `retaildemand` +
  `commissionreportin`) НЕ тронут.** Бриф ограничивает scope правки `STAGING_SCHEMA` и
  `_build_merge_sql`; периметр использует отдельную схему (`PERIMETER_STAGING_SCHEMA`) без поля
  `owner` — источники периметра (`entity/retaildemand`, `entity/commissionreportin`) не были
  частью этой правки и не читались на предмет наличия аналогичного поля.

### `reference/code/cf-facts/MANIFEST.md` — НЕ тронут (решение, а не молчаливый пропуск)

Бриф допускает правку MANIFEST.md «если каталог ведёт провенанс патчей». Проверено сплошным
поиском истории (`git log --all --oneline -- reference/code/cf-facts/MANIFEST.md`,
`reference/_scratch_SALES-DOCUMENT-OWNER-INGEST_2026-08-07/manifest_decision_check.log`):
файл правился ровно по фактам реального деплоя (`SALES-INGEST-PATCH-DEPLOY`,
`DQ-GATE-SCOPE-SPLIT-DEPLOY`) или первого снятия снапшота из облака (`CODE-REPO-SEED-REST`).
Прецедент того же класса работы — `SALES-INGEST-PATCH` (2026-08-03, подготовка патча периметра
без деплоя, `reference/sales_ingest_patch_2026-08-03.md`) — MANIFEST.md своей сессией не
трогал: провенанс на этапе подготовки патча живёт в отдельном `/reference`-отчёте, MANIFEST.md
фиксирует только read-back после факта деплоя. Эта сессия следует тому же правилу: MANIFEST.md
не правится, провенанс патча — в этом файле.

---

## Что НЕ сделано (явно, по scope брифа)

- Патч НЕ задеплоен — деплой `cf-facts` заводится отдельной будущей задачей (класс B, требует
  ADR), по факту готовности этого патча.
- `02_ERP_CONTRACTS.md` НЕ правился — документирование новой колонки контрактом откладывается на
  отдельный ADR при принятии решения.
- `reference/sql/sq_marts_sales_overview.sql` НЕ правился — вне scope до появления поля в `core`
  (решение владельца после деплоя).
- Живого `GET` к МойСкладу не выполнялось — форма поля `owner.meta.href` подтверждена ранее
  офлайн, чтением сохранённого тела `reference/_scratch_PARITY-CHECK-SALES-RETURNS_2026-08-01/demand_page_0.json`.
- Строка `Q-78` НЕ закрыта целиком — эта задача даёт только правку загрузчика (снапшот); полное
  закрытие зависит от деплоя и последующего решения владельца по витрине.

---

## Провенанс поля-источника

`entity/demand`, возвращаемый МойСкладом, несёт поле `owner`, формат идентичен уже читаемому
`agent.meta.href`:

```json
"owner": {"meta": {"href": ".../entity/employee/90ff70de-8162-11ef-0a80-0262000b020c", "type": "employee", ...}}
```

Подтверждено ранее (не этой сессией): `reference/sales_employee_attribution_2026-08-07.md §3` —
чтение сохранённого тела `reference/_scratch_PARITY-CHECK-SALES-RETURNS_2026-08-01/demand_page_0.json`,
ключ `owner.meta.href`. Состав правки (файл-за-файлом) взят дословно из того же `§3`.

---

## Открытый технический вопрос (НЕ решён этой сессией, зафиксирован явно)

**Версионируется ли `owner` документа `entity/demand` отдельно от самого документа?**

Известный прецедент противоположного поведения — `dim_counterparties.owner_employee_id`
(«текущий менеджер» контрагента) хранится через SCD2 (`scd2_valid_from`/`scd2_valid_to`/
`scd2_is_current`, `02_ERP_CONTRACTS.md`, `ADR-089`), то есть у МойСклада ЕСТЬ прецедент
раздельного версионирования владельца сущности от версии самой сущности.

Если `owner` документа `entity/demand` МЕНЯЕТСЯ независимо от полей документа (правится не вместе
с `updated` документа) — правка, добавленная этой сессией, несёт снимочный характер: значение
`document_owner_employee_id` в `core.fact_sales_profit` будет отражать владельца НА МОМЕНТ
загрузки строки в `MERGE` (текущий снимок при `WHEN NOT MATCHED`), а не историю смен владельца, и
при последующих `MERGE`-прогонах не обновится (поле НЕ входит в `WHEN MATCHED THEN UPDATE SET`,
см. выше) — то есть если владелец документа сменится ПОСЛЕ первой загрузки строки, `core` этого
изменения не увидит вовсе.

Если же `owner` документа версионируется отдельно от документа (как `dim_counterparties`) — вопрос
о корректном моменте снятия снимка (какая версия `owner` соответствует конкретной позиции
документа) требует отдельного решения, аналогичного `ADR-089` для контрагента.

**Этот вопрос НЕ проверяется данной сессией ни замером, ни обращением к документации API** —
проверка требует либо живого запроса к МойСкладу (класс B, вне мандата этой сессии), либо
документации API МойСклада (вне репозитория, вне мандата класса A). Вопрос остаётся открытым и
переходит в реестр гэпов (см. session-блок).

---

## Дифф — сводка

```
 reference/code/cf-facts/bq_ops.py        |  6 ++++++
 reference/code/cf-facts/fetch_demands.py | 12 ++++++++++++
 2 files changed, 18 insertions(+)
```

Полный текст диффа — в коммите этой сессии (`git show` по SHA коммита патча).
