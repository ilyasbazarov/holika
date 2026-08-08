# TASK BRIEF · T-DQ-FRESHNESS-COVERAGE

**Класс задачи (ADR-076):** A
<Чтение репо и облака (read-only), запись только в `/reference` (включая снапшот `reference/code/cf-dq/`), коммит без push. Совпадает с `07_STATE.md §Мандат Claude Code`, строка «DQ-FRESHNESS-COVERAGE, подготовка». Деплой CF (класс B) — отдельная строка мандата «DQ-FRESHNESS-COVERAGE, деплой», мандат НЕ выдан; в scope этой задачи не входит.>

**Параллель (ADR-082 §1, уточнён `ADR-083 §1`):** нет
<Совпадает с `07_STATE.md §Мандат Claude Code`. Перед реальным параллельным запуском с другой задачей всё равно обязателен `bash tools/parallel_check.sh <TASK1> <TASK2>`.>

**Файлы на запись** (полный список; на нём МЕХАНИЧЕСКИ проверяется пересечение при параллельном
запуске — `tools/parallel_check.sh`, `ADR-083 §1`):
- `reference/code/cf-dq/` — снапшот CF `cf-dq`: новые функции проверок свежести добавляются рядом с существующими (`main.py`, `config.py`, `helpers.py`), ничего не деплоится
- `reference/dq_freshness_coverage_<date>.md` — артефакт: дизайн проверок, вывод порогов из каденции, SQL, результаты `dry_run`

## Роль
Ты — исполнитель проекта. Законы — `CLAUDE.md`, стандарты — `05_CONVENTIONS.md` Части I и II.
Модель исполнения: ты исполняешь сам (`ADR-082 §2`). Не-идемпотентное — `deploy`, `run`, `update`,
прод-`bq query`, `git push` — только отдельным действием после явного подтверждения владельца,
никогда в связке с диагностикой. `Done` — только по подтверждённому логу, не по `rc=0`.
Работаешь в СВОЁМ рабочем дереве и коммитишь в СВОЮ ветку (`ADR-081 §6`). `07_STATE`,
`06_DECISIONS_LOG` и `06_INDEX` не правишь: session-блок кладёшь файлом в `reference/_inbox/`.

**Уточнение по этой задаче:** `bq query --dry_run` против живых таблиц — read-only, разрешён классом A
(прецедент `SALES-MERGE-DRYRUN`, `07_STATE.md:1518`, «в `allow`»). Живой `bq query` без `--dry_run`,
любой `gcloud functions deploy`, любая правка `workflow*.yaml` в проде — вне scope, не исполнять.

## Цель
Спроектировать и подготовить (БЕЗ деплоя) две проверки свежести — техническую (блокирующая по форме,
но пока нигде не подключена) и бизнес-диагностическую (без порога, только печать величины) — для шести
фактовых таблиц ядра, у которых сегодня нет вообще никакого наблюдателя: `core.fact_returns`,
`core.fact_purchases`, `core.fact_inventory`, `core.fact_payments`, `core.fact_customer_invoices`,
`core.fact_commissionreportin`. Для `core.fact_customer_invoices` проверки уже спроектированы другой
задачей — эта сессия их не переизобретает, только переносит и сверяет форму. Результат — код в снапшоте
`reference/code/cf-dq/` и самодостаточный артефакт `/reference`. Деплой и подключение к живому `cf-dq`/
`workflow.yaml` — отдельные задачи (`DQ-FRESHNESS-COVERAGE, деплой`, класс B, мандат не выдан).

## Context-to-load (обязательно прочитать перед работой)
- `_METHOD`, `00_CHARTER`, `05_CONVENTIONS`, `07_STATE` (всегда, читаются с диска по именам)
- `02_ERP_CONTRACTS.md` §схемы core — схемы `core.fact_returns`, `core.fact_purchases`, `core.fact_inventory` (колонки `_loaded_at` + бизнес-дата у каждой)
- `03_PIPELINE_SPEC.md` §DQ — форма трёх порогов свежести (не примиряются в одно число, `ADR-007`); пример вывода порога `≤ 2 часа` для часового пайплайна как «два пропущенных прогона»
- `01_ARCHITECTURE.md` §DAG — состав шагов `msklad-pipeline-hourly` (`step_purchases` NON-BLOCKING, окно 90 дней)
- `11_INFRA_FACTS.md` — инвентарь Cloud Scheduler: `msklad-pipeline-hourly` (`0 * * * *`), `msklad-pipeline-weekly` (`0 1 * * 0`), `cf-inventory-trigger` (`0 21 * * *`), `finance-daily-update` (`0 3 * * *` Asia/Bishkek), `loss-commission-daily-update` (`0 3 * * *` Asia/Bishkek)
- `reference/schema_dump_2026-07-28.md` §core.fact_payments, §core.fact_commissionreportin, §core.fact_customer_invoices — точные схемы (эти три таблицы НЕ перенесены в `02_ERP_CONTRACTS.md`, читать только отсюда, не выдумывать структуру)
- `reference/invoices_loader_design_2026-08-02.md` §9 (целиком: 9.1–9.4) — уже готовый образец формы для `core.fact_customer_invoices`: проверка (A) техническая по `_loaded_at`, порог `48 часов`, вывод порога из формы часового правила (`03_PIPELINE_SPEC.md:86`, «`≤ 2 часа` → для суточного `≤ 48 часов`»); проверка (B) бизнес-свежесть по `moment`, диагностическая, БЕЗ порога (осознанный отказ, порог не выводим из ничего); инвариант «один стамп `_loaded_at` на прогон» (§6.4 того же артефакта) — без него проверка (A) неоднозначна
- `reference/code/cf-dq/main.py` — текущий `check_freshness` (строки 70-86) как канонический код-стиль: `run_row`/`run_scalar` из `helpers.py`, возврат `(passed: bool, detail: str)`
- `reference/code/cf-dq/config.py` — где живут константы порогов (`DQ_FRESHNESS_MAX_DAYS` и т.п.) — новые пороги кладутся сюда же по той же форме
- `reference/code/cf-facts/fetch_purchases.py`, `reference/code/cf-facts/fetch_returns.py` — источник для проверки инварианта «один стамп `_loaded_at` на прогон» у `fact_purchases`/`fact_returns`
- `reference/code/cf-finance/main.py` (пишет `fact_payments`) и `reference/code/cf-loss-commission/main.py` (пишет `fact_commissionreportin`) — тот же инвариант для этих двух таблиц
- `reference/code/cf-inventory/main.py` — тот же инвариант для `fact_inventory`
- `07_GAPS.md` строка `DQ-FRESHNESS-COVERAGE` — полный текст задачи, гейт снят фактом (`ADR-140 §последствия`)
Если чего-то из списка нет в контексте → выдай `CONTEXT GAP` и остановись.

## Входы
**Шесть таблиц и источник их каденции (факт, не вывод сессии — уже установлено в репо):**

| Таблица | Загрузчик / шаг | Расписание (`11_INFRA_FACTS.md`) | Класс каденции |
|---|---|---|---|
| `core.fact_purchases` | `step_purchases`, `msklad-pipeline-hourly` (NON-BLOCKING) | `0 * * * *` | часовая |
| `core.fact_returns` | `step_returns`, `msklad-pipeline-weekly` (только weekly) | `0 1 * * 0` | недельная |
| `core.fact_inventory` | `cf-inventory-trigger` | `0 21 * * *` (UTC) | суточная |
| `core.fact_payments` | `finance-daily-update` (`cf-finance`) | `0 3 * * *` Asia/Bishkek | суточная |
| `core.fact_commissionreportin` | `loss-commission-daily-update` (`cf-loss-commission`) | `0 3 * * *` Asia/Bishkek | суточная |
| `core.fact_customer_invoices` | суточный загрузчик (`INVOICES-LOADER` программа) | суточная (по конструкции T1-T6) | суточная — проверки УЖЕ спроектированы, см. ниже |

**Уже готовый образец (не переделывать, переносить как есть):** `core.fact_customer_invoices`,
проверки (A)/(B), полный текст — `reference/invoices_loader_design_2026-08-02.md §9.2`. Порог (A) —
`load_lag_hours <= 48`. Порог (B) — не назначен (осознанно).

**Схемы (бизнес-дата + `_loaded_at` в каждой таблице):**
- `core.fact_returns`: `return_date` DATE, `_loaded_at` TIMESTAMP (`02_ERP_CONTRACTS.md:88-101`)
- `core.fact_purchases`: `order_date` DATE, `_loaded_at` TIMESTAMP (`02_ERP_CONTRACTS.md:62-84`)
- `core.fact_inventory`: `date_snapshot` DATE, `_loaded_at` TIMESTAMP (`02_ERP_CONTRACTS.md:103-117`)
- `core.fact_payments`: `moment` DATE, `_loaded_at` TIMESTAMP (`reference/schema_dump_2026-07-28.md:151-169`)
- `core.fact_commissionreportin`: `moment` TIMESTAMP, `_loaded_at` TIMESTAMP (`reference/schema_dump_2026-07-28.md:84-97`)
- `core.fact_customer_invoices`: `moment` DATE, `_loaded_at` TIMESTAMP (`reference/schema_dump_2026-07-28.md:98-115`)

**Форма вывода порога (A), уже установлена прецедентом и не выдумывается заново:**
`порог_часов = 2 × период_каденции_в_часах` («два пропущенных прогона», `03_PIPELINE_SPEC.md:86`, применено
к суточному загрузчику как `≤ 2ч → ≤ 48ч` в `reference/invoices_loader_design_2026-08-02.md §9.2`). По этой
же формуле: часовая каденция → `2ч`; суточная → `48ч`; недельная → `336ч` (`14` суток).

## Шаги
1. Прочитать весь Context-to-load. Сверить первую строку каждого файла (`ADR-054`).
2. Для каждой из пяти ЕЩЁ не спроектированных таблиц (`fact_returns`, `fact_purchases`, `fact_inventory`,
   `fact_payments`, `fact_commissionreportin`) открыть соответствующий загрузчик и подтвердить инвариант
   «один стамп `_loaded_at` на прогон» (аналог `reference/invoices_loader_design_2026-08-02.md §6.4`) —
   без этого подтверждения проверка (A) для этой таблицы неоднозначна. Если инвариант НЕ подтверждается
   чтением кода — не подставлять правдоподобное, зафиксировать как открытый вопрос конкретно по этой
   таблице (не блокирует остальные пять) и не писать для неё проверку (A) как готовую.
3. Для каждой из шести таблиц (включая перенос готового для `fact_customer_invoices`) собрать пару
   проверок по форме `reference/invoices_loader_design_2026-08-02.md §9.2`:
   - **(A) техническая свежесть** — `TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), MAX(_loaded_at), HOUR) <= порог`,
     порог по формуле шага «Входы» выше, с явным показом расчёта (каденция → порог) для каждой таблицы;
   - **(B) бизнес-свежесть** — `DATE_DIFF(CURRENT_DATE('Asia/Bishkek'), MAX(<бизнес-дата>), DAY)`,
     диагностика, без порога, только величина для печати (тот же осознанный отказ, что и у `fact_customer_invoices`, `§9.2`, не назначать порог без эмпирики).
4. Оформить обе проверки как Python-функции по стилю `reference/code/cf-dq/main.py:70-86`
   (`run_row`/`run_scalar` из `helpers.py`, возврат `(passed: bool, detail: str)`), добавить в снапшот
   рядом с существующими проверками, НЕ включая их в список `CHECKS`, исполняемый `main()` — эта задача
   не подключает проверки к живому гейту (подключение и деплой — отдельная задача класса B). Пороги —
   новые именованные константы в `reference/code/cf-dq/config.py`, по форме уже существующих
   (`DQ_FRESHNESS_MAX_DAYS` и т.п.), с комментарием, из какой каденции выведено число.
5. Провалидировать SQL каждой из 12 (6 таблиц × 2 проверки, включая перенесённую пару invoices) проверок
   через `bq query --dry_run` против живых таблиц (read-only, класс A). Логи — в артефакт.
6. Собрать `reference/dq_freshness_coverage_<date>.md`: по каждой таблице — источник каденции (ссылка на
   `11_INFRA_FACTS.md`/`01_ARCHITECTURE.md`), вывод порога (A), текст обеих проверок, результат
   `dry_run`, статус инварианта «один стамп на прогон» (подтверждён/не подтверждён и почему). Для
   `fact_customer_invoices` — явная пометка «перенесено без изменений» с точной ссылкой на источник,
   не пересказывать заново.
7. Если на любом шаге инструмент запросит деплой/живую запись/несогласованное состояние — не продолжать
   слепым retry (`★ Не-идемпотентные операции`), зафиксировать как гэп/блокер.

## Критерии приёмки (Acceptance)
- Для всех шести таблиц есть текст обеих проверок ((A) техническая + (B) бизнес-диагностика), КРОМЕ
  случаев, где шаг 2 не подтвердил инвариант «один стамп на прогон» — там прямо назван открытый вопрос
  вместо готового кода, а не правдоподобная догадка.
- Порог (A) каждой таблицы имеет явно показанный вывод из факта каденции (`11_INFRA_FACTS.md`/
  `01_ARCHITECTURE.md`), не назначен произвольно.
- Все спроектированные SQL прошли `bq query --dry_run` без синтаксических ошибок; лог приложен.
- Код лежит ТОЛЬКО в `reference/code/cf-dq/` (снапшот), ничего не задеплоено, список `CHECKS` в
  `main.py` не тронут (проверки не подключены к исполнению).
- `reference/dq_freshness_coverage_<date>.md` самодостаточен и трассируется к источникам.
- Session-блок подан в `reference/_inbox/`.

## Что вернуть человеку (Return-this)
- Путь к `reference/dq_freshness_coverage_<date>.md`.
- Диф/новые функции в `reference/code/cf-dq/` (какие файлы правились).
- Короткая сводка: сколько из шести таблиц получили обе готовые проверки, у скольких инвариант
  «один стамп на прогон» не подтвердился (и что это значит для следующего шага).
- Команда, которой владелец может перепроверить `dry_run` самостоятельно.

## Вне scope этой задачи
- Деплой `cf-dq` и подключение новых проверок к списку `CHECKS`/к `workflow.yaml` (`DQ-FRESHNESS-COVERAGE,
  деплой`, класс B, мандат не выдан).
- Назначение порога для проверки (B) — осознанно не делается (нет эмпирики), как и у `fact_customer_invoices`.
- Путь сигнала/алертинга (`DQ-ALERT-FILTER-FIX`, отдельная задача, мандат не выдан).
- Перепроектирование самой проверки для `fact_customer_invoices` — она уже готова, только переносится.
- Любая правка `workflow_hourly.yaml`/`workflow_weekly.yaml` (эти файлы уже правились задачей
  `DQ-GATE-SCOPE-SPLIT` и деплоятся отдельно).

## В конце сессии
Выдай SESSION-блок по формату `05_CONVENTIONS` Часть III
(`SESSION_LOG` / `STATE_PATCH` / `NEW_DECISIONS` / `NEW_CONVENTIONS`).
