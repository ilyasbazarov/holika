# TASK BRIEF · E1-T1-MECH

**Сгенерирован:** 2026-07-26 · **Роль генератора:** архитектор
**Репо-пин:** `bee5a10e4e751a26f5ac8d53bd3d002153c03025` (перечитывать по этому SHA; если есть новее — перепиннить и сверить `07_STATE`)

## Роль

Ты — разработчик проекта. Сначала прочитай `_METHOD` + `05_CONVENTIONS` (правила агента), затем действуй.
Модель исполнения: ты ПИШЕШЬ код/артефакты, человек ЗАПУСКАЕТ и возвращает логи. Ты не исполняешь сам.

## Цель

Переписать SQL scheduled query `sq_marts_expenses` так, чтобы `marts.expenses` собиралась из **трёх** источников вместо одного: `core.fact_payments` (как сейчас) + `core.fact_loss` + `core.fact_commissionreportin`. Форма таблицы (17 колонок) сохраняется без изменений. Правка проверяется на копии, прод-конфиг переключается отдельным гейтом с разрешения владельца.

## Context-to-load (обязательно прочитать перед работой)

- `_METHOD` — https://raw.githubusercontent.com/ilyasbazarov/holika/bee5a10e4e751a26f5ac8d53bd3d002153c03025/_METHOD.md
- `00_CHARTER` — https://raw.githubusercontent.com/ilyasbazarov/holika/bee5a10e4e751a26f5ac8d53bd3d002153c03025/00_CHARTER.md
- `05_CONVENTIONS` — https://raw.githubusercontent.com/ilyasbazarov/holika/bee5a10e4e751a26f5ac8d53bd3d002153c03025/05_CONVENTIONS.md
- `07_STATE` — https://raw.githubusercontent.com/ilyasbazarov/holika/bee5a10e4e751a26f5ac8d53bd3d002153c03025/07_STATE.md
- `06_DECISIONS_LOG` §ADR-006 (методология статей), §ADR-011 (фантомные записи), §ADR-012 (март на fact_payments), §ADR-016 (валютная починка), §ADR-024 (развязка ингеста и FX), §ADR-031 (ингест списаний/комиссий), §ADR-032…036 (решения под эту задачу) — https://raw.githubusercontent.com/ilyasbazarov/holika/bee5a10e4e751a26f5ac8d53bd3d002153c03025/06_DECISIONS_LOG.md
- `11_INFRA_FACTS` §SQ (Config ID, расписание) — https://raw.githubusercontent.com/ilyasbazarov/holika/bee5a10e4e751a26f5ac8d53bd3d002153c03025/11_INFRA_FACTS.md
- Живой SQL марта — https://raw.githubusercontent.com/ilyasbazarov/holika/bee5a10e4e751a26f5ac8d53bd3d002153c03025/reference/sql/sq_marts_expenses.sql
- Эталон П&Л за май — https://raw.githubusercontent.com/ilyasbazarov/holika/bee5a10e4e751a26f5ac8d53bd3d002153c03025/reference/pnl_2026-05.md
- Код ингеста списаний/комиссий — https://raw.githubusercontent.com/ilyasbazarov/holika/bee5a10e4e751a26f5ac8d53bd3d002153c03025/reference/code/cf-loss-commission/main.py

Если чего-то из списка нет в контексте → выдай `CONTEXT GAP` и остановись.

## Входы (все проверены фактом 2026-07-26)

**Прод-объект, который правим:**
- Scheduled query `sq_marts_expenses`, `transferConfig` = `6a22a243-…` (полный ID — в `11 §SQ`)
- Расписание: **ежедневно ~11:10 UTC**, стратегия записи **WRITE_TRUNCATE** (стирает и пересобирает целиком)
- Цель: `marts.expenses`, 17 колонок

**Источники:**

| Таблица | Колонок | Что есть | Что отсутствует |
|---|---|---|---|
| `core.fact_payments` | — | всё, что нужно марту сейчас | — |
| `core.fact_loss` | 13 | `expense_item_id/name`, `agent_id`, `sum_kgs`, `applicable` | `project_name`, `sales_channel_name`, `payment_type`; `project_id`/`sales_channel_id`/`agent_name` фактически NULL во всех строках |
| `core.fact_commissionreportin` | 9 | `agent_id`, `reward_sum_kgs`, `commission_overhead_sum_kgs`, `sum_kgs` | статья, проект, канал, контрагент-имя, `applicable` |

**Контрольные цифры за май 2026 (проверены запросом 2026-07-26):**

| Источник | Сумма, KGS |
|---|---|
| `core.fact_payments` | 8 600 919,01 |
| `core.fact_loss` (`applicable = TRUE`) | 1 193 254,77 |
| `core.fact_commissionreportin` | 438 729,42 |
| **Итого трёх** | **10 232 903,20** |
| Целевая величина сверки из эталона | **10 232 903,20** |
| **Разрыв** | **0,00** |

Постатейно за май совпадение тоже подтверждено: `Вывод прибыли` 4 246 163,66 · `Банк (комиссия)` 191 459,01 · `Маркетинг и реклама` 275 463,00 (платежи) + 751 438,54 (списания) = 1 026 901,54 · `Прочие расходы` 54 008,00 (платежи) + 29 977,29 (списания) = 83 985,29 · `Расходы маркетплейсов` 141 945,56 (платежи) + 438 729,42 (комиссии) = 580 674,98 · `Списания` 411 838,94 (только списания).

**Валютный баг ADR-016 закрыт фактом:** ревизия `cf-finance-00012-cik`, деплой 2026-07-20, умножение на курс в коде (строки 66–68), в архиве лежит до-фиксовая версия с хешем `7a5d8dcd…181d`. Все пять проверенных статей за май сходятся с эталоном → починка доехала до данных. Смешанного состояния (ADR-024 §5) **больше нет**, раздельная приёмка не нужна.

## Шаги

**Шаг 0 — гейт заливки истории (без этого дальше нельзя).**
На 2026-07-26 в `core.fact_loss` 8 строк, в `core.fact_commissionreportin` 7 — **только май**. Ночной джоб `loss-commission-daily-update` на момент проверки **ни разу не запускался** (`lastAttemptTime: None`), первый запуск — 03:00 Asia/Bishkek. Тело вызова = `{}`, а код при пустом теле берёт окно `2020-01-01 → завтра`, то есть **всю историю**. Значит после первого прогона таблицы должны наполниться до ~128 списаний и ~191 комиссии.

Проверить, что прогон состоялся и залил историю:

```sql
SELECT 'loss' AS src, FORMAT_DATE('%Y-%m', DATE(moment)) AS ym, COUNT(*) AS docs
FROM `msklad-bi-prod.core.fact_loss` GROUP BY 1,2
UNION ALL
SELECT 'commission', FORMAT_DATE('%Y-%m', DATE(moment)), COUNT(*)
FROM `msklad-bi-prod.core.fact_commissionreportin` GROUP BY 1,2
ORDER BY 1,2
```

Если по-прежнему только `2026-05` → выдай `CONTEXT GAP`, не продолжай: правка марта на майских данных даст правильный май и пустые списания за все прочие месяцы.

**Шаг 1 — снять типы `moment` во всех трёх таблицах.**
Живой SQL применяет к `moment` функции `DATE_TRUNC` и `FORMAT_DATE`, которые требуют `DATE`. В новых таблицах `moment` объявлен `TIMESTAMP`. Если типы не совпадают, `UNION ALL` упадёт или изменит семантику. Снять фактом:

```
bq show --schema --format=prettyjson msklad-bi-prod:core.fact_payments
```

Если типы разные — добавить явный каст **в ветках union**, чтобы выражения ниже остались байт-в-байт как в живом SQL. Не переписывать `DATE_TRUNC`/`FORMAT_DATE` под новый тип: это меняет поведение существующих колонок.

**Шаг 2 — написать новый SQL.**
Черновик ниже — **форма, а не готовый текст**. Проверить каждую строку, не принимать на веру:

```sql
WITH fx AS (
  SELECT rate_kgs_per_usd
  FROM `msklad-bi-prod.core.dim_fx_rates`
  ORDER BY date DESC
  LIMIT 1
),
src AS (
  -- ветка 1 · платежи (логика существующего марта, без изменений)
  SELECT
    p.moment,
    p.payment_type,
    p.expense_item_id,
    COALESCE(p.expense_item_name, 'Не указана') AS expense_item_name,
    p.agent_id,
    COALESCE(p.agent_name, 'Не указан')         AS agent_name,
    p.project_id,
    COALESCE(p.project_name, 'Не указан')       AS project_name,
    p.sales_channel_id,
    COALESCE(p.sales_channel_name, 'Не указан') AS sales_channel_name,
    p.sum_kgs
  FROM `msklad-bi-prod.core.fact_payments` p
  WHERE p.moment IS NOT NULL

  UNION ALL

  -- ветка 2 · списания (ADR-032, ADR-034)
  SELECT
    l.moment,
    'loss'                                      AS payment_type,
    l.expense_item_id,
    COALESCE(l.expense_item_name, 'Не указана') AS expense_item_name,
    l.agent_id,
    COALESCE(l.agent_name, 'Не указан')         AS agent_name,
    l.project_id,
    'Не указан'                                 AS project_name,
    l.sales_channel_id,
    'Не указан'                                 AS sales_channel_name,
    l.sum_kgs
  FROM `msklad-bi-prod.core.fact_loss` l
  WHERE l.moment IS NOT NULL
    AND l.applicable                            -- ADR-034: черновики режем здесь

  UNION ALL

  -- ветка 3 · комиссии маркетплейсов (ADR-006 §2, ADR-032)
  SELECT
    c.moment,
    'commission'                 AS payment_type,
    CAST(NULL AS STRING)         AS expense_item_id,
    'Расходы маркетплейсов'      AS expense_item_name,
    c.agent_id,
    'Не указан'                  AS agent_name,
    CAST(NULL AS STRING)         AS project_id,
    'Не указан'                  AS project_name,
    CAST(NULL AS STRING)         AS sales_channel_id,
    'Не указан'                  AS sales_channel_name,
    c.sum_kgs
  FROM `msklad-bi-prod.core.fact_commissionreportin` c
  WHERE c.moment IS NOT NULL
)
SELECT
  s.moment,
  DATE_TRUNC(s.moment, MONTH)                     AS month_start,
  DATE_TRUNC(s.moment, WEEK(SATURDAY))            AS week_start,
  EXTRACT(YEAR FROM s.moment)                     AS year_num,
  FORMAT_DATE('%Y-%m', s.moment)                  AS year_month,
  s.payment_type,
  s.expense_item_id,
  s.expense_item_name,
  s.agent_id,
  s.agent_name,
  s.project_id,
  s.project_name,
  s.sales_channel_id,
  s.sales_channel_name,
  COUNT(*)                                        AS payment_count,
  ROUND(SUM(s.sum_kgs), 2)                        AS total_sum_kgs,
  ROUND(SUM(s.sum_kgs) / fx.rate_kgs_per_usd, 2)  AS total_sum_usd
FROM src s
LEFT JOIN fx ON TRUE
WHERE s.moment IS NOT NULL
GROUP BY
  s.moment, month_start, week_start, year_num, year_month,
  s.payment_type, s.expense_item_id, s.expense_item_name,
  s.agent_id, s.agent_name, s.project_id, s.project_name,
  s.sales_channel_id, s.sales_channel_name,
  fx.rate_kgs_per_usd
ORDER BY s.moment DESC
```

Три вещи, которые надо проверить глазами, а не предположить:
- порядок и имена 17 колонок на выходе **идентичны** живому SQL — иначе дашборд отвалится;
- `COALESCE` на `expense_item_name` в ветках union и **отсутствие** второго `COALESCE` во внешнем SELECT — как в живом SQL;
- `payment_type` получает два новых значения `loss` и `commission`. Если на дашборде есть фильтр по этой колонке с зашитым списком значений — новые значения там не появятся сами. Проверить и сообщить человеку.

**Шаг 3 — собрать результат в отдельную таблицу, прод не трогать.**
Запустить новый SQL как обычный запрос с записью в `marts.expenses_staging` (создать, если нет). Прод-`transferConfig` не редактировать, расписание не ставить на паузу — на этом шаге он вообще не участвует.

**Шаг 4 — сверить staging с эталоном.**
Отдать человеку запросы, которые считают по `marts.expenses_staging`: итог за май; постатейную разбивку за май; и разницу `expenses_staging` минус `expenses` по месяцам (чтобы увидеть, что изменилось и только там, где ожидалось).

**Шаг 5 — стоп. Гейт владельца.**
Собрать результаты сверки в один короткий отчёт и остановиться. Переключение прода — отдельное разрешение владельца, не часть этого шага и не «если всё сошлось, то можно».

## Критерии приёмки (Acceptance)

1. `marts.expenses_staging` за май 2026: `SUM(total_sum_kgs)` по всем статьям **минус** `Перемещение исходящий` **плюс** `Налоги и сборы` = **10 232 903,20**, разрыв **0,00**.
2. Постатейно за май совпадают с эталоном все статьи из таблицы контрольных цифр выше, включая `Списания` 411 838,94, `Маркетинг и реклама` 1 026 901,54, `Прочие расходы` 83 985,29, `Расходы маркетплейсов` + `Комиссия` = 580 674,98.
3. Набор и порядок колонок в `expenses_staging` **побайтово** совпадает с `marts.expenses` (проверяется сравнением `bq show --schema` обеих таблиц).
4. Разница `expenses_staging` минус `expenses` по месяцам объяснена целиком: она равна суммам из `fact_loss` + `fact_commissionreportin` за те же месяцы и ничему больше.
5. Прод-`transferConfig` `6a22a243-…` на момент сдачи **не изменён** (подтверждается `bq show --transfer_config`).

## Что вернуть человеку (Return-this)

- Готовый текст SQL одним блоком, пригодным для вставки в консоль BigQuery.
- Точные команды на создание `expenses_staging` и на прогон сверки — в формате ADR-014: один блок, сам создаёт файл, сам запускает, вывод в файл, временные папки не удаляет.
- Короткий отчёт сверки: пять пунктов приёмки, по каждому фактическое число и «сошлось / не сошлось».
- Явную строку: прод не тронут, для переключения нужно отдельное разрешение.

## Вне scope этой задачи

- **Переключение прода.** Это `E1-T1-MECH-CUTOVER`, отдельная задача с гейтом владельца и процедурой pause → правка → проверка отсутствия текущего прогона → возврат расписания.
- **Правка кода загрузчиков.** Ни `cf-loss-commission`, ни `cf-finance` не трогаем (ADR-034).
- **Догон названий проекта и канала для списаний.** Пустоты заполняются `'Не указан'` (ADR-036). Разбирательство, почему они NULL, — отдельная задача.
- **Курс USD.** Живой SQL применяет последний курс из `dim_fx_rates` ко всей истории. Поведение сохраняется как есть; это отдельный открытый вопрос, не править здесь.
- **Дашборд.** Пересборка визуалов, новые фильтры, слияние `Комиссия` с `Расходы маркетплейсов` на уровне отчёта — вне scope.
- **Таблица соответствий названий статей.** Не создаётся, вариантов написания в данных нет (ADR-035).

## В конце сессии

Выдай SESSION-блок по формату `05_CONVENTIONS` Часть III (`SESSION_LOG` / `STATE_PATCH` / `NEW_DECISIONS` / `NEW_CONVENTIONS`).
