# FILE: invoices_backfill_2026-08-03.md

## INVOICES-BACKFILL — проверка закрытия пропущенного периода `2026-06-05`…дата запуска

**Класс задачи:** B. **Мандат:** выдан владельцем в чате постфактум 2026-08-04 (форма прецедента
`ADR-092 §1`, `06_DECISIONS_LOG.md:2559 §1`) — отдельным сообщением до гейта объявлены объект
(`msklad-bi-prod.core.fact_customer_invoices`, read-only), объём (шаги 1-5 брифа, ровно read-only
`SELECT`/`bq show`) и откат (не требуется, состояние таблицы не менялось). Формализация ADR-номера —
за проходом сборки, не за этой сессией.

**Дата исполнения:** 2026-08-04. **Исполнитель:** сессия `INVOICES-BACKFILL` (рабочее дерево
`worktrees/INVOICES-BACKFILL`, ветка `s/INVOICES-BACKFILL`).

## 1. Лог запуска

```
$ date -u
Tue Aug  4 05:55:45 UTC 2026

$ gcloud auth list
     Credentialed Accounts
ACTIVE  ACCOUNT
*       ilyasbazarov4@gmail.com
```

## 2. Живая схема `core.fact_customer_invoices` (`bq show --format=prettyjson`)

```
invoice_id           STRING   REQUIRED
invoice_name         STRING
moment                DATE
agent_id             STRING
agent_name           STRING
state_id             STRING
state_name           STRING
sum_kgs              FLOAT
payed_sum_kgs        FLOAT
unpaid_sum_kgs       FLOAT
payment_planned      DATE
sales_channel_id     STRING
sales_channel_name   STRING
_loaded_at           TIMESTAMP
```

Партиционирования/кластеризации нет (`timePartitioning`/`clustering`/`requirePartitionFilter`
отсутствуют в JSON-ответе) — совпадает с `reference/invoices_loader_design_2026-08-02.md §5`.
Колонка документа-даты — `moment` (`DATE`, правило `DATE(M+6ч)`, `ADR-088`, design §296) — та, по
которой ведётся сплошное перечисление суток ниже.

## 3. Сплошное перечисление суток `2026-06-05`…`2026-08-03` (build калeндаря + LEFT JOIN)

Запрос (`reference/_scratch_INVOICES-BACKFILL_2026-08-04/query_full_calendar.sql`):

```sql
WITH calendar AS (
  SELECT day AS doc_date
  FROM UNNEST(GENERATE_DATE_ARRAY('2026-06-05', '2026-08-03')) AS day
),
counts AS (
  SELECT
    moment AS doc_date,
    COUNT(*) AS row_count
  FROM `msklad-bi-prod.core.fact_customer_invoices`
  WHERE moment BETWEEN '2026-06-05' AND '2026-08-03'
  GROUP BY doc_date
)
SELECT
  c.doc_date,
  IFNULL(k.row_count, 0) AS row_count
FROM calendar c
LEFT JOIN counts k USING (doc_date)
ORDER BY c.doc_date
```

Полный построчный вывод (60 суток, все напечатаны, ни одни не пропущены молча;
провенанс-файл — `reference/_scratch_INVOICES-BACKFILL_2026-08-04/query_full_calendar_output.csv`):

```
doc_date,row_count
2026-06-05,3
2026-06-06,2
2026-06-07,0
2026-06-08,16
2026-06-09,0
2026-06-10,3
2026-06-11,17
2026-06-12,72
2026-06-13,0
2026-06-14,2
2026-06-15,7
2026-06-16,9
2026-06-17,1
2026-06-18,24
2026-06-19,35
2026-06-20,0
2026-06-21,0
2026-06-22,0
2026-06-23,1
2026-06-24,10
2026-06-25,1
2026-06-26,14
2026-06-27,0
2026-06-28,0
2026-06-29,1
2026-06-30,0
2026-07-01,31
2026-07-02,0
2026-07-03,3
2026-07-04,0
2026-07-05,0
2026-07-06,0
2026-07-07,0
2026-07-08,23
2026-07-09,1
2026-07-10,16
2026-07-11,0
2026-07-12,0
2026-07-13,0
2026-07-14,1
2026-07-15,25
2026-07-16,0
2026-07-17,44
2026-07-18,0
2026-07-19,0
2026-07-20,0
2026-07-21,1
2026-07-22,4
2026-07-23,1
2026-07-24,46
2026-07-25,0
2026-07-26,0
2026-07-27,3
2026-07-28,0
2026-07-29,34
2026-07-30,2
2026-07-31,9
2026-08-01,25
2026-08-02,0
2026-08-03,0
```

26 суток из 60 несут `row_count=0`. Список нулевых суток НЕ ограничен выходными: среди них есть
будни (`2026-06-09` вт, `2026-06-22` пн, `2026-06-30` вт, `2026-07-02` чт, `2026-07-06` пн,
`2026-07-07` вт, `2026-07-13` пн, `2026-07-16` чт, `2026-07-20` пн, `2026-07-28` вт) — то есть
разброс нулевых суток сам по себе НЕ является автоматическим признаком пробела загрузки: он
согласуется с неравномерным (пачками) выставлением счетов, что видно и по ненулевым суткам —
счётчик прыгает от `1` до `72` без видимой периодичности.

## 4. Проверка непрерывности с источником (шаг 5 — без нового живого GET)

Источник фактов — боевой прогон `INVOICES-LOADER-DEPLOY` 2026-08-03
(`reference/invoices_loader_deploy_2026-08-03.md:71,116,118`), кэшированный, новый живой `GET` не
делался:

```
fetched=4526 meta_size=4526   (fetched = источнику МойСклад, GET entity/invoiceout БЕЗ фильтра по дате)
staged=4526
MERGE: 4526 строк, merged_deleted=2 (синтетические строки прежней тестовой сессии, законно удалены)
Итог в core.fact_customer_invoices: 4526 строк, load_lag_hours=0, total_sum_kgs=1 279 111 083,57
```

Проверка данной сессии — общее число строк живой таблицы совпадает с `4526` боевого прогона
(read-only, без нового `GET`):

```sql
SELECT COUNT(*) AS total_rows, MIN(moment) AS min_date, MAX(moment) AS max_date
FROM `msklad-bi-prod.core.fact_customer_invoices`
```

Вывод:

```
total_rows,min_date,max_date
4526,2024-10-04,2026-08-01
```

`total_rows=4526` совпадает с `fetched=meta_size=4526` боевого прогона — таблица не потеряла ни
одной строки между `GET` источника и текущим состоянием. Поскольку `GET entity/invoiceout` шёл
БЕЗ фильтра по дате (design §6.6), а `fetched` точно равен `meta_size` (объявленному источником
общему числу документов), пагинация не потеряла ни одного документа НИГДЕ в истории, включая
целевой диапазон `2026-06-05`…`2026-08-03`. Это прямая read-only сверка непрерывности с источником
в рамках допустимого этой задачей (шаг 5 брифа: «внутренний счёт core», без построчной сверки —
она вне scope, `INVOICES-PARITY-RECHECK`).

`max_date=2026-08-01` — счетов с `moment` после `2026-08-01` в источнике нет вовсе (не техническая
причина: `2026-08-02` и `2026-08-03` дают `row_count=0` потому, что таких документов не существует
в МойСкладе на момент `GET`, а не потому, что загрузчик их не подтянул — `fetched=meta_size`
исключает потерю).

Свежесть после деплоя (справочно, вне критериев приёмки):

```sql
SELECT COUNT(DISTINCT _loaded_at) AS distinct_load_stamps, MAX(_loaded_at) AS last_load
FROM `msklad-bi-prod.core.fact_customer_invoices`
```

```
distinct_load_stamps,last_load
1,2026-08-03 22:00:02 UTC
```

`22:00:02 UTC` = `04:00:02` Бишкек `2026-08-04` — совпадает с расписанием `invoices-daily-update`
(`0 4 * * * Asia/Bishkek`), то есть минимум один суточный прогон сверх боевого уже прошёл к моменту
этой сессии, как и предупреждал бриф. `distinct_load_stamps=1` — отдельное наблюдение, не влияет на
вердикт (`total_rows` и `fetched=meta_size` уже дают факт непрерывности независимо от числа
прогонов).

## 5. Вердикт

**Пробелов нет. Досев пропущенного периода `2026-06-05`…дата запуска закрыт побочным продуктом
деплоя `INVOICES-LOADER-DEPLOY` (2026-08-03), фактом на 2026-08-04.**

Основание:
1. Сплошное перечисление 60 суток целевого диапазона напечатано построчно (раздел 3) — нулевые
   сутки есть, но их распределение (будни вперемешку с выходными, соседство с сутками с `row_count`
   от `1` до `72`) согласуется с неравномерным выставлением счетов, а не с систематическим
   исключением по дате.
2. Read-only сверка непрерывности с источником (раздел 4): `total_rows=4526` живой таблицы точно
   равен `fetched=meta_size=4526` боевого `GET entity/invoiceout` БЕЗ фильтра по дате — пагинация
   не потеряла ни одного документа во всей истории, включая целевой диапазон.
3. `max_date=2026-08-01` объясняет нулевые `2026-08-02`/`2026-08-03` отсутствием документов в
   источнике, не технической потерей.

`INVOICES-BACKFILL` закрывается **DONE**.

## Провенанс

- `reference/_scratch_INVOICES-BACKFILL_2026-08-04/query_full_calendar.sql`
- `reference/_scratch_INVOICES-BACKFILL_2026-08-04/query_full_calendar_output.csv`
- `reference/_scratch_INVOICES-BACKFILL_2026-08-04/query_daily_counts.sql` (черновой запрос без
  сплошного перечисления — вытеснен запросом раздела 3, оставлен как есть, провенанс шага)
- `reference/_scratch_INVOICES-BACKFILL_2026-08-04/query_daily_counts_output.csv`
- `reference/_scratch_INVOICES-BACKFILL_2026-08-04/schema_check.txt`
- `reference/_scratch_INVOICES-BACKFILL_2026-08-04/load_stamps.csv`
- `reference/invoices_loader_deploy_2026-08-03.md` (источник фактов боевого прогона)
