# TASK BRIEF · T-LS-RETURNS-FX-HARDCODE

**Класс задачи (ADR-076):** A
(Подготовка текста SQL-запроса Custom Query — не интерфейс Looker Studio, поэтому запись только в
`/reference` по букве `ADR-076 §1`/`ADR-091 §1`. Совпадает с `07_STATE.md` §Мандат Claude Code,
строка «LS-RETURNS-FX-HARDCODE, подготовка текста» — класс A, параллель «да», мандат постоянный.
Вставка исправленного текста в интерфейс Looker Studio и read-back — ОТДЕЛЬНАЯ строка мандата
«LS-RETURNS-FX-HARDCODE, правка в интерфейсе» — класс B, «НЕ отдаётся», за владельцем; в scope
этой сессии НЕ входит.)

**Параллель (ADR-082 §1, уточнён `ADR-083 §1`):** да
(Перед параллельным запуском — `bash tools/parallel_check.sh` с именем этой задачи и именем
второй, `09_RUNBOOK`, режим П.)

**Файлы на запись** (полный список; на нём МЕХАНИЧЕСКИ проверяется пересечение при параллельном
запуске — `tools/parallel_check.sh`, `ADR-083 §1`):
- `reference/sql/fact_returns.sql` — переписывается на исправленный текст запроса (курс, период, поле-обманка)

## Роль
Ты — исполнитель проекта. Законы — `CLAUDE.md`, стандарты — `05_CONVENTIONS.md` Части I и II.
Модель исполнения: ты исполняешь сам (`ADR-082 §2`). `Done` — только по подтверждённому логу
(здесь — по успешному dry-run запроса), не по факту записи файла. Работаешь в СВОЁМ рабочем
дереве и коммитишь в СВОЮ ветку (`ADR-081 §6`). `07_STATE`, `06_DECISIONS_LOG` и `06_INDEX` не
правишь: session-блок кладёшь файлом в `reference/_inbox/`.

## Цель
Заменить в снятом Custom Query `fact_returns` (`reference/sql/fact_returns.sql`) три дефекта одной
правкой: литерал курса `87.4`, литерал скользящего окна `INTERVAL 90 DAY` и поле-обманку
`rate_kgs_per_usd` (сейчас алгебраически тождественное `total_return_sum_usd`). Результат — текст
запроса, готовый к вставке владельцем в Looker Studio; сама вставка и read-back — вне scope
(отдельная строка мандата класса B).

## Context-to-load (обязательно прочитать перед работой)
- `_METHOD`, `00_CHARTER`, `05_CONVENTIONS`, `07_STATE` (всегда, читаются с диска по именам)
- `02_ERP_CONTRACTS.md` §`core.fact_returns` (схема: `return_id`, `return_type`, `return_date`,
  `product_id`, `agent_id`, `quantity`, `sum_kgs`, `cost_kgs`, `has_basis`, `_loaded_at`) и
  §`core.dim_fx_rates` (схема: `date` DATE, `rate_kgs_per_usd` FLOAT64) — сверить актуальность по
  живой схеме перед правкой (`ADR-087 §7` — состав/имена колонок берутся с живой схемы, не со
  снимка, если снимок успел устареть)
- `06_DECISIONS_LOG.md` — полный текст `ADR-087` (контракт Custom Query: период из параметров
  дашборда `@DS_START_DATE`/`@DS_END_DATE`, запрет литерального скользящего окна, §5/§6 — эта
  задача) и `ADR-062` (политика исходящей FX-конвертации, критерий — наличие дневного зерна в
  строке витрины; §2/§5/§6 — форма правки копируется с эталона `supplier_price_history`, не
  изобретается)
- `reference/ls_custom_queries_2026-07-30.md` — инвентарь Custom Query, строка `fact_returns`
  (страница «Executive summary», дата-контрол есть) и раздел «Наблюдения по составу» п.3/4
- `reference/sql/fact_returns.sql` — текущий AS-IS снимок (дословный текст, ещё не правленный)
- `reference/sql/supplier_price_history.sql` — эталон формы «курс по дате с деградацией»
  (`LEFT JOIN core.dim_fx_rates fx ON fx.date = …` плюс `COALESCE` на последний известный курс)
- `reference/sql/msklad_expenses.sql` и `reference/sql/msklad_counterparty_returns.sql` — образец
  использования параметров дашборда (`WHERE … PARSE_DATE('%Y%m%d', @DS_START_DATE) … @DS_END_DATE`)

Если чего-то из списка нет в контексте → выдай `CONTEXT GAP` и остановись.

## Входы
- `reference/sql/fact_returns.sql` — снятый дословный текст запроса (снимок 2026-07-30):
  ```sql
  SELECT
    return_date,
    SUM(sum_kgs)                     AS total_return_sum_kgs,
    SUM(sum_kgs) / 87.4              AS rate_kgs_per_usd,
    SUM(sum_kgs / 87.4)              AS total_return_sum_usd,
    COUNT(DISTINCT return_id)        AS return_doc_count,
    COUNT(*)                         AS return_positions
  FROM `msklad-bi-prod.core.fact_returns`
  WHERE return_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY)
  GROUP BY return_date
  ```
- Три названных дефекта (`reference/ls_custom_queries_2026-07-30.md`, `07_GAPS.md` строка
  `LS-RETURNS-FX-HARDCODE`):
  1. Курс `87.4` вписан литералом, не привязан к `core.dim_fx_rates`.
  2. Поле `rate_kgs_per_usd` по формуле тождественно `total_return_sum_usd`
     (`SUM(x)/87.4 = SUM(x/87.4)`), то есть колонка с именем курса несёт сумму.
  3. Период — скользящее окно `INTERVAL 90 DAY`, не параметры дашборда, хотя на странице
     «Executive summary» есть дата-контрол (`ADR-087 §6`).

## Шаги
1. Перечитать текущий снимок и схемы `core.fact_returns`/`core.dim_fx_rates` — убедиться, что
   имена колонок не разошлись со снимком `02_ERP_CONTRACTS.md`/`reference/schema_dump_*` (если
   есть доступ, свериться с живой схемой BigQuery; расхождение со снимком — не гэп, а повод
   довериться живой схеме, `ADR-087 §7`).
2. Заменить период: убрать `WHERE return_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY)` на
   фильтр по параметрам дашборда, по образцу `msklad_expenses.sql`/`msklad_counterparty_returns.sql`
   (`ADR-087 §1`, `§5`/`§6` — это та же задача, что чинит курс, дробить нельзя).
3. Заменить курс: `return_date` — дневное зерно строки витрины (группировка идёт по нему), поэтому
   по критерию `ADR-062 §2` применяется курс ПО ДАТЕ, а не «последний курс». Скопировать форму
   `supplier_price_history.sql` — `LEFT JOIN core.dim_fx_rates fx ON fx.date = return_date` плюс
   `COALESCE` на последний известный курс для дат вне покрытия (`ADR-062 §6` — граница деградации
   `core.dim_fx_rates.min_date`, отдельно не расследуется, только не даёт запросу упасть на NULL).
4. Убрать поле-обманку: после шага 3 `fx.rate_kgs_per_usd` — независимая от суммы величина
   (реальный курс дня), тождественность с шагом 2 исчезает по построению. `total_return_sum_usd`
   считается через тот же `fx.rate_kgs_per_usd` (`SUM(sum_kgs) / fx.rate_kgs_per_usd` либо
   `SUM(sum_kgs / fx.rate_kgs_per_usd)` — выбрать форму, согласованную с `GROUP BY return_date,
   fx.rate_kgs_per_usd`, обе арифметически эквивалентны при одном курсе на группу).
5. Обновить служебный комментарий-шапку файла (провенанс уже существующего снимка не редактируется
   задним числом — дописать новый блок под ним: дата правки, задача, что исправлено, кто ещё не
   вставил/не сверил — вставка в интерфейс и read-back остаются за владельцем).
6. Валидация без исполнения на живых данных: `bq query --dry_run --use_legacy_sql=false` над
   готовым текстом (только синтаксис/типы, не запись, не изменение прод-состояния — read-only
   проверка, класс A). Лог dry-run — часть Return-this.

## Критерии приёмки (Acceptance)
- В тексте запроса нет литерала курса (`87.4` или любого другого числового литерала-курса).
- В тексте запроса нет литерала скользящего окна (`INTERVAL … DAY` в фильтре периода); период
  фильтруется через `@DS_START_DATE`/`@DS_END_DATE`.
- Поле `rate_kgs_per_usd` не тождественно алгебраически полю `total_return_sum_usd` (разные
  формулы, независимые источники значения).
- `bq query --dry_run` над готовым текстом проходит без ошибок синтаксиса/типов — лог приложен.
- Файл `reference/sql/fact_returns.sql` содержит только этот один правленный запрос плюс
  комментарий-провенанс (старый AS-IS блок не удаляется, дописывается новый).

## Что вернуть человеку (Return-this)
- Обновлённый `reference/sql/fact_returns.sql` (диф).
- Точная команда и полный вывод `bq query --dry_run` (или эквивалента) над готовым текстом.
- Итоговый текст SQL одним блоком — для вставки владельцем в Looker Studio (отдельным действием,
  вне этой сессии).

## Вне scope этой задачи
- Вставка запроса в интерфейс Looker Studio и read-back (класс B, строка мандата «правка в
  интерфейсе», НЕ отдаётся инструменту).
- `LS-PERIOD-CONTRACT` (исключения §2 `ADR-087` для других Custom Query) — отдельная задача.
- Пересмотр политики исходящей FX-конвертации (`ADR-062`, `Q-19`, owner-gated) — здесь только
  ПРИМЕНЯЕТСЯ уже принятое правило, новое решение не принимается.
- Правка других Custom Query (`msklad_counterparty_returns`, `msklad_inventory_latest` и т.д.).

## В конце сессии
Выдай SESSION-блок по формату `05_CONVENTIONS` Часть III
(`SESSION_LOG` / `STATE_PATCH` / `NEW_DECISIONS` / `NEW_CONVENTIONS`), положи файлом в
`reference/_inbox/session_LS-RETURNS-FX-HARDCODE_<date>.md`.
