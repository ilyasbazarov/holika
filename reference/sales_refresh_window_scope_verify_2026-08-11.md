# FILE: sales_refresh_window_scope_verify_2026-08-11.md

# Независимая проверка патча «область удаления по происхождению строки» (вариант 1)

**Задача:** `SALES-REFRESH-WINDOW-SCOPE-VERIFY` (класс A, роль — исполнитель-проверяющий, не
автор патча). **База:** `bdeace3`. **Проверяемый предмет:** патч из
`reference/sales_refresh_window_rollback_adj_2026-08-11.md` §7, закоммиченный в ветке
`s/SALES-REFRESH-WINDOW-ROLLBACK-ADJ` @ `0e9b0fc8114758614367c950c7e50d03aa8dac83` (в мою ветку
не смержен — прочитан через `git show`, снапшот скопирован в
`reference/_scratch_SALES-REFRESH-WINDOW-SCOPE-VERIFY_2026-08-11/patch_snapshot/`, ничего не
изменено и не задеплоено). **Дата:** 2026-08-11.

---

## 1. Импорты

`fetch_perimeter.py:59` — `from config import PERIMETER_CHANNEL_COMMISSION, PERIMETER_CHANNEL_RETAIL`
(импорта раньше не было вовсе — подтверждено). Имена совпадают с объявленными в `config.py:65-67`:
`PERIMETER_CHANNEL_RETAIL`, `PERIMETER_CHANNEL_COMMISSION`, `PERIMETER_CHANNEL_NAMES`.

`bq_ops.py:29-38` — `from config import (... PERIMETER_CHANNEL_NAMES, ...)`, использован на
`bq_ops.py:228` (`_PERIMETER_NAMES_SQL = "(" + ", ".join(...) + ")"`).

`python3 -m py_compile config.py fetch_perimeter.py bq_ops.py main.py` → **rc=0**, без ошибок,
для всех четырёх файлов.

**Результат: пройдено.**

## 2. Направление условия в ветке продаж

`bq_ops.py:395-397` (продажи, `_build_merge_sql`):
```
AND NOT (T.sales_channel_id IS NULL
         AND COALESCE(T.sales_channel_name, '') IN {_PERIMETER_NAMES_SQL})
THEN DELETE
```
Отрицание внешнее, над всей скобкой — удаляется всё, ЧТО НЕ «строка периметра». Строка
периметра определяется как `sales_channel_id IS NULL AND имя IN ('Розница','Комиссия')`.
Значит ветка продаж удаляет всё, КРОМЕ периметра — направление верное, не перевёрнуто.

`bq_ops.py:710-712` (периметр, `_build_perimeter_merge_sql`):
```
AND T.sales_channel_id IS NULL
AND COALESCE(T.sales_channel_name, '') IN {_PERIMETER_NAMES_SQL}
THEN DELETE
```
Без отрицания — удаляет ТОЛЬКО периметр. Симметрично и корректно.

**Результат: пройдено.**

## 3. COALESCE в обеих ветках

Присутствует в обеих: `bq_ops.py:396` (продажи) и `bq_ops.py:711` (периметр) —
`COALESCE(T.sales_channel_name, '') IN {_PERIMETER_NAMES_SQL}`. Без него `NULL IN (...)` даёт
`NULL` (не `FALSE`), и строка с пустым именем канала не попадает ни под TRUE, ни под FALSE ветки
сравнения — комментарий патча (`bq_ops.py:393-394`) называет это явно, поведение осознанное.
Проверено, что при этом различитель — ПАРА полей (`sales_channel_id IS NULL` — обязательное
условие сначала), то есть обычная продажа с пустым именем канала, но заполненным
`sales_channel_id`, под периметр не подходит ни при каком значении `COALESCE`.

**Результат: пройдено.**

## 4. Отрендеренный SQL

Функции `_build_merge_sql(CORE_BYVARIANT_BCK, 90)` и `_build_perimeter_merge_sql(90)` вызваны
напрямую из снапшота патча (`rendered_sales_merge.sql`, `rendered_perimeter_merge.sql`,
`reference/_scratch_SALES-REFRESH-WINDOW-SCOPE-VERIFY_2026-08-11/patch_snapshot/`). Предикат
попал в текст в обеих ветках (см. §2/§3 — цитаты взяты из ОТРЕНДЕРЕННОГО файла, не из исходника).
Кортеж меток экранирован корректно: `IN ('Розница', 'Комиссия')` — обе метки не содержат
апострофа, экранирующий код (`.replace("'", "''")`) не проверен на реальном апострофе (в данных
его нет), но сама конструкция синтаксически валидна — подтверждено прохождением dry-run (§5).

**Результат: пройдено.**

## 5. Холостой прогон (--dry_run)

Лог: `reference/_scratch_SALES-REFRESH-WINDOW-SCOPE-VERIFY_2026-08-11/patch_snapshot/dryrun_run.log`
(UTC-якорь и `gcloud auth list` первой и последней командой).

```
=== sales merge dry-run ===
Query successfully validated. Assuming the tables are not modified, running this query will
process upper bound of 12122434 bytes of data.
=== perimeter merge dry-run ===
Query successfully validated. Assuming the tables are not modified, running this query will
process upper bound of 13230550 bytes of data.
```

Оба MERGE валидны против живых таблиц.

**Результат: пройдено.**

## 6. Разбиение `core.fact_sales_profit` — свой запрос

Собственный запрос (не копия чужого, `split_check.sql` в том же каталоге), классифицирующий
КАЖДУЮ строку живой таблицы тем же предикатом, что несёт периметрийная ветка удаления:

```sql
WITH classified AS (
  SELECT CASE
    WHEN sales_channel_id IS NULL
     AND COALESCE(sales_channel_name, '') IN ('Розница', 'Комиссия')
      THEN 'perimeter' ELSE 'sales' END AS bucket
  FROM `msklad-bi-prod.core.fact_sales_profit`
)
SELECT bucket, COUNT(*) AS n FROM classified GROUP BY bucket ORDER BY bucket;
```

Результат (`split_check_run.log`, `2026-08-11T11:18:38Z`): `perimeter = 5578`, `sales = 37417`,
`COUNT(*)` всей таблицы отдельным запросом = `42995`. Сумма частей (`5578 + 37417 = 42995`)
**точно равна** общему счётчику — зазора и пересечения нет, подтверждено арифметически по
собственным числам, не по чужим.

**Расхождение с ориентиром из брифа найдено и не подогнано под него:** заявленные в
`sales_refresh_window_rollback_adj_2026-08-11.md §7` числа — `42975 = 5578 + 37397` (периметр
совпадает, продажи и итог расходятся на `20` строк). Коллизия различителя проверена отдельным
запросом (`collision_check.sql`) — строк с `sales_channel_id IS NOT NULL` и именем канала из
`('Розница','Комиссия')` **0** за всю историю, то есть расхождение не связано с дефектом
предиката. Таблица живая (промоуты штатно исполняются), между измерением архитектора
(подготовка патча, ранее 2026-08-11) и этим замером (`11:18:38Z`) прошло значимое время —
объяснение «выросло на 20 строк новыми продажами» согласуется с тем, что периметр (число
`5578`) не изменился вовсе, а прирост целиком в ветке продаж. Это наблюдение, не находка о
дефекте: разбиение остаётся точным (сумма = итог) на любой момент снятия.

**Результат: пройдено** (по существу проверки — полнота разбиения); **числовой ориентир
брифа устарел на 20 строк** (объяснимо дрейфом живых данных, не дефектом).

## 7. `main.py` — умолчание и вызывающие

`main.py:166` — `def _run_weekly_load(run_id: str, window_days: int = WEEKLY_WINDOW_DAYS) -> dict:`
Умолчание равно `WEEKLY_WINDOW_DAYS` (`config.py:41` → `90`) — то же значение, что было жёстко
зашито до патча. Единственный вызывающий — `main.py:96`, внутри `mode == "weekly"`, других
вызовов `_run_weekly_load` в снапшоте нет (`grep -n "_run_weekly_load" main.py` — 2 совпадения:
объявление и один вызов).

**Находка (не дефект поведения, дефект формулировки патча):** утверждение патча
(`sales_refresh_window_rollback_adj_2026-08-11.md §7` п.4) — «штатный конвейер передаёт `90`
явно (`workflow_weekly.yaml:70`)» — **не подтверждается текстом файла**. Строка `70` в снимке
`workflow_weekly.yaml` — это `mode: "weekly"` внутри `step_facts`; тело запроса этого шага
(`workflow_weekly.yaml:63-71`) несёт ТОЛЬКО `run_id` и `mode`, поля `window_days` там нет.
Явную передачу `window_days: 90` несут ДРУГИЕ четыре шага того же файла — `returns` (:123),
`perimeter` (:151), `promote` (:217), `perimeter_promote` (:244) — но не `weekly` (:70).

Фактический механизм иной и не задокументирован патчем: `main.py:81-88` вычисляет
`_default_window_days = WEEKLY_WINDOW_DAYS if mode == "weekly" else ...` и
`window_days = int(body.get("window_days", _default_window_days))` — то есть при отсутствии
`window_days` в теле запроса для `mode="weekly"` подстановка `90` происходит ВНУТРИ `main()`,
а не потому, что workflow передаёт его явно. Итоговое поведение сегодня совпадает (`90` в обоих
случаях — из тела запроса при явной передаче, из умолчания `main()` при её отсутствии), поэтому
это **не функциональный дефект**, но формулировка патча ссылается на несуществующую строку
конфигурации как на источник инварианта. Хрупкость: если позже `_default_window_days` изменится
(например, режим `topoff` получит другое умолчание), поведение `weekly` изменится молча, а
патч документирует защиту, которой в этом месте нет.

**Результат: логика (умолчание/единственный вызывающий) — пройдено; текстовое утверждение о
`workflow_weekly.yaml:70` — не подтверждено, это находка.**

## 8. Сплошной поиск — другие ветки удаления и третий писатель

`grep -n "DELETE\|TRUNCATE\|WHEN NOT MATCHED BY SOURCE" *.py` по всем файлам снапшота патча
(`config.py`, `fetch_perimeter.py`, `bq_ops.py`, `main.py`) — единственные `THEN DELETE`
находятся на `bq_ops.py:397` и `bq_ops.py:712`, обе уже проверены (§2/§3). Остальные совпадения
`TRUNCATE` — все `WRITE_TRUNCATE` в staging-таблицы и в `core.fact_purchases`/`core.fact_returns`
(независимые от `fact_sales_profit`, полный refresh — не MERGE, `05_CONVENTIONS §C1/§C2` к ним
неприменимо).

Писатели `core.fact_sales_profit` сплошным поиском по всему репо (не только по патчу):
- `bq_ops.py::promote_to_core` (`_build_merge_sql`) — MERGE обычных продаж, патчен.
- `bq_ops.py::_run_perimeter_promote`/периметрийный MERGE (`_build_perimeter_merge_sql`) — патчен.
- `reference/code/cf-dq/main.py:15` — `CORE_FACT = ...fact_sales_profit`, используется только в
  `SELECT COUNT(*)`/DQ-проверках (`:65-73`, `:112-117`) — **read-only**, не писатель.
- `reference/sql/sq_marts_sales_overview.sql:4` и прочие `reference/sql/*.sql` — читают
  `FROM core.fact_sales_profit` для пересборки `marts.*` (`CREATE OR REPLACE TABLE`) —
  **читатели**, не писатели `core.fact_sales_profit`.
- `11_INFRA_FACTS.md:70` — упоминание правила `C1`, не отдельный писатель.

Третьего писателя нет. Других веток удаления, кроме двух уже проверенных, в снапшоте нет.

**Результат: пройдено.**

---

## Вердикт

**Проверка пройдена.** Все восемь пунктов подтверждены доказательством (номер строки/файла,
вывод команды, число). Патч по варианту 1 корректен: направление предиката не перевёрнуто,
`COALESCE` на месте в обеих ветках, отрендеренный SQL проходит `--dry_run` против живых таблиц,
разбиение таблицы полное без зазора и пересечения, третьего писателя и посторонних веток
удаления нет.

Найдены две вещи, требующие внимания архитектора ДО выдачи нового мандата, ни одна не является
дефектом самого предиката удаления:

1. **§7 п.4 патча цитирует несуществующую строку.** `workflow_weekly.yaml:70` НЕ передаёт
   `window_days` явно для `mode="weekly"` — совпадение с `90` достигается умолчанием
   `_run_weekly_load(..., window_days=WEEKLY_WINDOW_DAYS)` и умолчанием `body.get(...,
   _default_window_days)` в `main.py`, а не workflow-файлом. Поведение сегодня безопасно
   (обе подстановки дают `90`), но формулировка патча вводит в заблуждение о механизме защиты.
2. **Числовой ориентир §7 устарел на 20 строк** (`42975` → живых `42995` на момент проверки) —
   объяснимо штатным приростом продаж между измерениями, само разбиение (сумма = итог, ноль
   коллизий) подтверждено заново и остаётся точным.

Рекомендация: перед деплоем поправить формулировку `§7 п.4` (назвать реальный механизм —
умолчание `main.py`, не строку workflow) либо явно решить, добавлять ли `window_days: 90` в шаг
`step_facts` workflow как страховку от будущего дрейфа `_default_window_days`. Числовой ориентир
разбиения не требует правки текста — он документирован как «ориентир», расхождение объяснено.

Провенанс всех команд и логов: `reference/_scratch_SALES-REFRESH-WINDOW-SCOPE-VERIFY_2026-08-11/`
(`patch_snapshot/` — снятые версии четырёх файлов + описания патча, отрендеренный SQL, логи
`dryrun_run.log`, `split_check_run.log`, `collision_check_run.log`).
