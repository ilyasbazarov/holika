# sales_merge_dryrun_2026-08-02 — SALES-MERGE-DRYRUN

## 0. Открывающий блок (цитаты дословно)

`07_STATE.md:476` (GAP-реестр, `SALES-MERGE-DRYRUN`):
> `SALES-MERGE-DRYRUN` | READY | Два технических неизвестных патча продаж: допустим ли `UPDATE`
> партиционирующей колонки внутри `MERGE`; источник COGS шире 7/90 суток | нет

`reference/parity_coarse_adj_2026-08-02.md` §4 (строка таблицы, ~строка 115):
> `SALES-MERGE-DRYRUN` | Снятие двух технических неизвестных варианта патча продаж: (а) допускает ли
> BigQuery `UPDATE` партиционирующей колонки `transaction_date` внутри `MERGE` — проверяется
> `bq query --dry_run`; (б) источник COGS для диапазона шире 7/90 суток — читается `fetch_byvariant.py`
> | A | По (а) — напечатанный ответ движка, не рассуждение; по (б) — либо назван источник с адресом в
> коде, либо `CONTEXT GAP`. Разгейчивает выбор одного из трёх вариантов

Мандат класса A (`07_STATE.md:356`): `SALES-MERGE-DRYRUN | A | да | постоянный | bq query --dry_run
(в allow) и чтение fetch_byvariant.py. Пишет: reference/sales_merge_dryrun_<date>.md`. Подтверждено
`.claude/settings.json:10`: `"Bash(bq query --dry_run*)"` присутствует в `allow`.

---

## 1. Вопрос (а) — допускает ли BigQuery `UPDATE` `transaction_date` внутри `MERGE`

**Ответ: ДА, движок валидирует запрос без ошибки** (с оговоркой метода, см. ниже).

### Метод
Тестовый запрос — `reference/_scratch_SALES-MERGE-DRYRUN_2026-08-02/test_merge.sql`, дословная копия
живого `_build_merge_sql` (`reference/code/cf-facts/bq_ops.py:176-303`), с `cogs_source_table =
core.fact_sales_profit_byvariant_backup` и `window_days = 7` (hourly-режим, как в дефолте
`main.py:70`). Единственное отличие от живого запроса — добавленная строка в
`WHEN MATCHED THEN UPDATE SET`:

```sql
T.transaction_date = S.transaction_date,
```

`ON`-клауза (`T.transaction_id = S.transaction_id AND T.transaction_date >= DATE_SUB(CURRENT_DATE(),
INTERVAL 7 DAY)`), источник `S` (тот же `SELECT` из `stg_msklad.fact_sales_staging` с JOIN на
`core.fact_sales_profit_byvariant_backup` и `core.dim_fx_rates`) и форма `WHEN NOT MATCHED THEN INSERT
(колонки) VALUES (...)` (C1, `ADR-030`) сохранены без изменений против живого кода.

Запрос нацелен на реальную таблицу `msklad-bi-prod.core.fact_sales_profit`, реальную
партиционирующую колонку `transaction_date` (`02_ERP_CONTRACTS.md:41`, DATE, без CAST), реальные
таблицы-источники (`stg_msklad.fact_sales_staging`, `core.fact_sales_profit_byvariant_backup`,
`core.dim_fx_rates`).

### Команда и лог

Скрипт `reference/_scratch_SALES-MERGE-DRYRUN_2026-08-02/run_dryrun.sh`:
```bash
bq query --use_legacy_sql=false --dry_run --project_id=msklad-bi-prod < test_merge.sql
```
`date -u` и `gcloud auth list` — первой и последней командой того же скрипта (`CLAUDE.md §★`).
Полный лог — `reference/_scratch_SALES-MERGE-DRYRUN_2026-08-02/run.log`.

```
=== date -u (start) ===
Sun Aug  2 15:04:11 UTC 2026
=== gcloud auth list (start) ===
     Credentialed Accounts
ACTIVE  ACCOUNT
*       ilyasbazarov4@gmail.com
=== bq query --dry_run (test_merge.sql) ===
Query successfully validated. Assuming the tables are not modified, running this query will process upper bound of 1338057 bytes of data.
=== gcloud auth list (end) ===
     Credentialed Accounts
ACTIVE  ACCOUNT
*       ilyasbazarov4@gmail.com
=== date -u (end) ===
Sun Aug  2 15:04:14 UTC 2026
```

`rc=0` **и** напечатанный план/bytes-estimate (`upper bound of 1338057 bytes`) присутствуют оба —
это факт, не голый `rc=0` (`ADR-021 §2`/`ADR-044`). Личность вызывающего (`ilyasbazarov4@gmail.com`)
одинакова в начале и конце, деградации авторизации посреди прогона нет.

### Оговорка метода (обязательна к прочтению перед использованием этого ответа)

Успешный dry-run **не доказывает**, что `UPDATE` пройдёт при реальном исполнении: dry-run не
гарантирует отсутствие runtime-ограничений (например, стоимости пересканирования партиций при
изменении партиционирующего значения — BigQuery в таком случае логически выполняет DELETE+INSERT
внутри движка, что дороже обычного `UPDATE`, но синтаксически/семантически ошибкой не является и
dry-run это не отражает в виде отказа). Формулировка гейтящей строки требует именно ответа
`bq query --dry_run`, и это он: **синтаксически и семантически движок запрос принимает**, ошибки нет.
Вопрос стоимости/производительности реального прогона остаётся вне этого замера.

---

## 2. Вопрос (б) — источник COGS для диапазона шире 7/90 суток

**Ответ: `CONTEXT GAP`.** Источник для диапазона шире 90 суток в коде не назван — ни явной веткой, ни
комментарием.

### Что установлено чтением

1. **`fetch_byvariant_cogs(token, date_from, date_to, session=None)`**
   (`reference/code/cf-facts/fetch_byvariant.py:54-58`) технически принимает произвольные
   `date_from`/`date_to` — подтверждено чтением ТЕЛА функции, не докстринга: `_weeks_in_range(date_from,
   date_to)` (`fetch_byvariant.py:40-51`) строит список недельных бакетов `WEEK(SATURDAY)` от
   `date_from` до `date_to` без обращения к какой-либо константе окна; каждый бакет запрашивается
   отдельным вызовом `report/profit/byvariant` (`fetch_byvariant.py:79-87`) с `momentFrom`/`momentTo`,
   вычисленными из самого бакета. Жёсткой привязки к `window_days` внутри функции нет.

2. **Единственный вызывающий код** — `reference/code/cf-facts/main.py:154,173`:
   ```
   date_from = date_to - timedelta(days=WEEKLY_WINDOW_DAYS)   # main.py:154
   ...
   byvariant_records = fetch_byvariant_cogs(token, date_from, date_to, session=session)  # main.py:173
   ```
   Это тело функции, исполняемой только веткой `mode == "weekly"` (`main.py:77-79`,
   `WEEKLY_WINDOW_DAYS = 90`, `reference/code/cf-facts/config.py:38`). Диспетчер режимов
   (`main.py:75-84`) перечисляет ровно пять веток — `hourly`, `weekly`, `promote`, `purchases`,
   `returns` — третьего случая «диапазон шире 90 суток» среди них нет.

3. **Выбор источника COGS на стороне `MERGE`** — `reference/code/cf-facts/bq_ops.py:331-346`
   (`promote_to_core`): `if window_days >= 90: cogs_source = STG_BYVARIANT` (с graceful degradation на
   `CORE_BYVARIANT_BCK`, если `STG_BYVARIANT` пуст), `else: cogs_source = CORE_BYVARIANT_BCK`. Условие
   бинарное (`>= 90` против остального) — веткой «диапазон шире 90» код не располагает; при
   `window_days`, например, 365 код возьмёт ту же ветку `STG_BYVARIANT`, но **`STG_BYVARIANT` к этому
   моменту наполнен только тем, что загрузил `fetch_byvariant_cogs` за предыдущие 90 суток от
   `main.py:154`** — то есть данные COGS для диапазона шире 90 суток физически отсутствуют в
   `STG_BYVARIANT`, а не «выбираются неверно»: проблема на шаг раньше выбора источника, в отсутствии
   вызова, наполняющего его для широкого диапазона.

### Формулировка гэпа

`fetch_byvariant_cogs` технически пригодна для произвольного диапазона (найдено чтением тела
функции, п.1), но в снапшоте `reference/code/cf-facts/` **нет вызывающего кода/режима**, передающего
ей `date_from`/`date_to` шире текущих 90 суток (`WEEKLY_WINDOW_DAYS`, единственный вызов —
`main.py:154,173`, жёстко привязанный к этой константе). Любому из вариантов патча
`SALES-REFRESH-WINDOW`, требующему COGS для более широкого/произвольного исторического диапазона
(например, вариант 1 «досев отдельным режимом» или вариант 2 «разовый пересев мая»), **придётся
ДОБАВИТЬ такой вызов** (передать собственные `date_from`/`date_to` в `fetch_byvariant_cogs` и
загрузить результат в `STG_BYVARIANT` до вызова `promote_to_core`), а не переиспользовать
существующий вызывающий код — переиспользовать можно только саму функцию `fetch_byvariant_cogs`.

Источник для диапазона шире 90 суток **не подставляется предположением** («наверное, будет
`STG_BYVARIANT`»): формально код выберет `STG_BYVARIANT` по условию `>= 90`, но это ничего не значит
без досева самого `STG_BYVARIANT` под нужный диапазон — то, что код сегодня не делает.

---

## 3. Итог

- Вопрос (а): закрыт напечатанным ответом движка BigQuery — dry-run успешен, ошибок нет
  (с методологической оговоркой §1 про runtime-стоимость, не про синтаксис/семантику).
- Вопрос (б): закрыт явным `CONTEXT GAP` — источник для диапазона шире 90 суток не назван в коде;
  паттерн выведен и адрес каждого факта указан.

**Строка GAP-реестра `SALES-REFRESH-WINDOW` разгейчена частично: вопрос (а) снят полностью, вопрос
(б) остаётся `CONTEXT GAP`, требующим решения владельца/архитектора (принять гэп как часть будущего
патча, требующего дописать код, либо запросить дополнительную discovery).** Выбор одного из трёх
вариантов патча `SALES-REFRESH-WINDOW` — по-прежнему решение владельца/архитектора, не этой сессии;
теперь оно опирается на два установленных факта вместо двух неизвестных.
