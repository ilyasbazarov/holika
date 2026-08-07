# FILE: sales_document_owner_deploy_prep_2026-08-07.md

# Доработка патча SALES-DOCUMENT-OWNER-INGEST перед деплоем — 2026-08-07

**Задача:** `SALES-DOCUMENT-OWNER-DEPLOY`, доработка патча (класс A, `ADR-136 §2`).
**Мандат:** класс A, постоянный (`07_STATE.md` §Мандат Claude Code, строка
`SALES-DOCUMENT-OWNER-DEPLOY, доработка патча`).
**Приёмка задана дословно строкой `07_GAPS.md` (`SALES-DOCUMENT-OWNER-DEPLOY`, `ADR-136 §2`).**

---

## Что сделано

В `reference/code/cf-facts/bq_ops.py`, функция `_build_merge_sql`, ветка
`WHEN MATCHED THEN UPDATE SET`, добавлена ровно одна строка:

```sql
T.document_owner_employee_id = S.document_owner_employee_id
```

Ничто другое в патче `SALES-DOCUMENT-OWNER-INGEST` не тронуто: `STAGING_SCHEMA`, `SELECT`
внутри `USING`, явный `INSERT (колонки)` (`C1`, `ADR-030`) и `reference/code/cf-facts/fetch_demands.py`
не менялись. `_build_perimeter_merge_sql` не тронута.

## Приёмка 1 — `git diff` снапшота

```diff
diff --git a/reference/code/cf-facts/bq_ops.py b/reference/code/cf-facts/bq_ops.py
index f6a4685..fb9cc1c 100644
--- a/reference/code/cf-facts/bq_ops.py
+++ b/reference/code/cf-facts/bq_ops.py
@@ -316,7 +316,8 @@ WHEN MATCHED THEN UPDATE SET
   T.project_id         = S.project_id,
   T.project_name       = S.project_name,
   T.discount        = S.discount,
-  T._loaded_at      = S._loaded_at
+  T._loaded_at      = S._loaded_at,
+  T.document_owner_employee_id = S.document_owner_employee_id
 
 WHEN NOT MATCHED THEN INSERT (
   transaction_id,
```

Ровно одна добавленная строка (`+ T.document_owner_employee_id = S.document_owner_employee_id`);
вторая строка diff-хунка — служебное добавление запятой к предыдущей строке, не новая колонка.

## Приёмка 2 — `python3 -m py_compile`

```
$ python3 -m py_compile reference/code/cf-facts/bq_ops.py && echo "py_compile OK"
py_compile OK
```

## Приёмка 3 — список колонок `UPDATE SET` vs `INSERT`

Проверочный скрипт и лог — `reference/_scratch_SALES-DOCUMENT-OWNER-DEPLOY_2026-08-07/verify_columns.py`
/ `verify_columns.log` (печатает совпавшие колонки поимённо, не текстовый вердикт — `ADR-044`).

**До правки:**
- `UPDATE SET` — 16 колонок.
- `INSERT` — 22 колонки.
- Различие (только в `INSERT`) — 6 колонок: `transaction_id`, `transaction_date`, `product_id`,
  `entity_type`, `agent_id`, `document_owner_employee_id`.

**После правки:**
- `UPDATE SET` — 17 колонок (добавлена `document_owner_employee_id`).
- `INSERT` — 22 колонки (не менялся).
- Различие (только в `INSERT`) — 5 колонок: `transaction_id`, `transaction_date`, `product_id`,
  `entity_type`, `agent_id`.

Различие после правки равно различию до неё **без** новой колонки — `document_owner_employee_id`
переместилась из «только в `INSERT`» в «в обеих ветках», больше ничего не сдвинулось. Оставшиеся
5 колонок — структурные (первичный ключ строки плюс `agent_id`, который сознательно не
обновляется, см. комментарий `bq_ops.py:55-56`) и правкой не затронуты.

## Что не менялось (подтверждение границ)

- `STAGING_SCHEMA` — без изменений.
- `SELECT` внутри `USING` (включая `s.document_owner_employee_id` в списке полей) — без изменений.
- Явный `INSERT (колонки) VALUES (…)` — без изменений (колонка уже была внесена патчем
  `SALES-DOCUMENT-OWNER-INGEST`).
- `reference/code/cf-facts/fetch_demands.py` — не открывался, не менялся.
- `_build_perimeter_merge_sql` — не менялась (проверено: единственный diff файла — показанный выше).

## Что этим НЕ делается (границы задачи)

- Ничего не задеплоено, живых `GET`/`gcloud`/`bq` вызовов не было.
- `ALTER TABLE core.fact_sales_profit ADD COLUMN` не исполнялся — это часть деплоя, класс B,
  мандат не выдан (`07_STATE.md`, строка `SALES-DOCUMENT-OWNER-DEPLOY, деплой`).
- `02_ERP_CONTRACTS.md` и `sq_marts_sales_overview.sql` не трогались.

## Состояние снапшота после правки

`reference/code/cf-facts/` после этой сессии несёт ровно один недеплоенный патч — сотрудник
документа (`document_owner_employee_id`, теперь и в `UPDATE SET`, и в `INSERT`). Смешения с
патчем метки канала (`SALES-PERIMETER-CHANNEL-DECIDE-DEPLOY`) больше нет — тот деплоен
(ревизия `cf-facts-00009-tul`). Равенства снапшота проду при этом нет: недеплоенный патч
сотрудника документа остаётся до отдельной задачи `SALES-DOCUMENT-OWNER-DEPLOY, деплой`
(класс B, мандат не выдан).

## Что должно быть учтено при будущем деплое (одной строкой, названо заранее в `ADR-136 §4`)

Первый прогон после будущего деплоя обязан идти режимом `weekly`, `window_days=90` — иначе
июль-2026 не попадает в окно `MERGE`; окно закрывается `2026-09-29` (`ADR-125 §5`).
