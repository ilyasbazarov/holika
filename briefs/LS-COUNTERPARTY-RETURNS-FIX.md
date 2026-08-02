# TASK BRIEF · T-LS-COUNTERPARTY-RETURNS-FIX

**Класс задачи (ADR-076):** A
<Подготовка текста. `07_STATE.md §Мандат Claude Code: класс задач`, строка `LS-COUNTERPARTY-RETURNS-FIX,
подготовка текста` (`07_STATE.md:332`): класс A, мандат постоянный. Вставка готового текста в интерфейс
Looker Studio и read-back (`07_STATE.md:333`) — класс B, владельцу, инструменту НЕ отдаётся (`ADR-085 §9`,
`ADR-091 §3`) и в эту задачу не входит.>

**Параллель (ADR-082 §1, уточнён `ADR-083 §1`):** да
<Совпадает с колонкой «Параллель» строки `LS-COUNTERPARTY-RETURNS-FIX, подготовка текста` (`07_STATE.md:332`).
Перед парным запуском — `bash tools/parallel_check.sh` (`ADR-082 §1`).>

**Файлы на запись** (полный список; на нём МЕХАНИЧЕСКИ проверяется пересечение при параллельном запуске):
- `reference/sql/msklad_counterparty_returns.sql` — переписывается новым текстом запроса (единственный
  файл, объявленный строкой мандата `07_STATE.md:332`)

## Роль
Ты — исполнитель проекта. Законы — `CLAUDE.md`, стандарты — `05_CONVENTIONS.md` Части I и II.
Модель исполнения: ты исполняешь сам (`ADR-082 §2`). Работаешь в СВОЁМ рабочем дереве и коммитишь в
СВОЮ ветку (`ADR-081 §6`). `07_STATE`, `06_DECISIONS_LOG` и `06_INDEX` не правишь: session-блок кладёшь
файлом в `reference/_inbox/`. `Done` — по проверяемому SQL-тексту, отвечающему приёмке ниже; вставка в
интерфейс и подтверждение цифрой live-дашборда в эту задачу не входят (класс B, владелец).

## Цель
Переписать текст Custom Query `msklad_counterparty_returns` (снимок — `reference/sql/msklad_counterparty_returns.sql`)
так, чтобы он закрывал четыре подтверждённых дефекта техдолга (`ADR-085 §8`, `07_GAPS.md:56`) и отвечал
приёмке `ADR-085 §10`, не нарушая контракт периода `ADR-087`. Результат — новый текст файла, готовый для
вставки владельцем в интерфейс Looker Studio; сама вставка и read-back — вне scope этой задачи.

## Context-to-load (обязательно прочитать перед работой)
- `_METHOD`, `00_CHARTER`, `05_CONVENTIONS`, `07_STATE` (всегда, читаются с диска по именам)
- `02_ERP_CONTRACTS.md` §схемы core — обязательно секции `core.fact_sales_profit` (строки 36-60) и
  `core.fact_returns` (строки 88-101); также §валюты/поведение-API если понадобится курс (в этой задаче
  курс не используется, обе стороны уже в KGS)
- `06_DECISIONS_LOG.md`: `ADR-085` §8-§10 (декомпозиция техдолга и дословная приёмка этой задачи),
  `ADR-087` §1, §3, §7 (контракт периода Custom Query: период — только из `@DS_START_DATE`/`@DS_END_DATE`,
  литеральное скользящее окно запрещено, `SELECT *` запрещён — этот запрос уже не использует `SELECT *`,
  проверить, что список колонок остаётся явным), `ADR-091` §2-§3 (текст SQL — класс A, разрез
  подготовка/вставка, read-back остаётся частью приёмки), `ADR-088` §3-§4 (правило суток по документу —
  для справки: `core.fact_returns.return_date` в текущем коде НЕ имеет установленного правила зоны времени,
  это дефект `INGEST-MOMENT-ZONE-FIX`, гейтится `Q-92`, этой задачей НЕ чинится)
- `reference/ls_custom_queries_2026-07-30.md` — инвентарь: этот запрос стоит на странице «Операционка»,
  таблица-основа `core.fact_sales_profit` + `core.dim_counterparties` + `core.fact_returns`
- `reference/sql/msklad_counterparty_returns.sql` — текущий (дефектный) текст запроса, дословный снимок
  живого интерфейса на 2026-07-30

Если чего-то из списка нет в контексте → выдай `CONTEXT GAP` и остановись.

## Входы

**Текущий текст запроса** (`reference/sql/msklad_counterparty_returns.sql`, снимок живого интерфейса
2026-07-30):

```sql
SELECT
  c.name                                              AS counterparty_name,
  f.agent_id,
  c.country,
  1                                                   AS counterparty_count,
  COALESCE(f.sales_channel_name, 'Не указан')         AS sales_channel_name,
  COALESCE(f.project_name, 'Не указан')               AS project_name,
  ROUND(SUM(f.revenue_kgs), 2)                        AS revenue_kgs,
  ROUND(SUM(COALESCE(f.margin_kgs, 0)), 2)            AS margin_kgs,
  ROUND(
    SAFE_DIVIDE(SUM(COALESCE(f.margin_kgs,0)), SUM(f.revenue_kgs)) * 100, 1
  )                                                   AS margin_pct,
  COALESCE(r.return_sum_kgs, 0)                       AS return_sum_kgs,
  ROUND(SUM(f.revenue_kgs) - COALESCE(r.return_sum_kgs, 0), 2)
                                                      AS net_revenue_kgs,
  ROUND(
    SAFE_DIVIDE(COALESCE(r.return_sum_kgs, 0), SUM(f.revenue_kgs)) * 100, 1
  )                                                   AS return_rate_pct,
  COUNT(DISTINCT f.transaction_date)                  AS transaction_date
FROM `msklad-bi-prod.core.fact_sales_profit` f
LEFT JOIN `msklad-bi-prod.core.dim_counterparties` c
  ON f.agent_id = c.agent_id AND c.scd2_is_current = TRUE
LEFT JOIN (
  SELECT agent_id, SUM(sum_kgs) AS return_sum_kgs
  FROM `msklad-bi-prod.core.fact_returns`
  WHERE return_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 365 DAY)
  GROUP BY agent_id
) r ON f.agent_id = r.agent_id
WHERE f.transaction_date BETWEEN PARSE_DATE('%Y%m%d', @DS_START_DATE)
                              AND PARSE_DATE('%Y%m%d', @DS_END_DATE)
GROUP BY c.name, f.agent_id, r.return_sum_kgs, c.country,
         f.sales_channel_name, f.project_name
ORDER BY revenue_kgs DESC
```

**Четыре подтверждённых дефекта** (`ADR-085 §8`, `07_GAPS.md:56`), дословно:
1. Возвраты за скользящие 365 дней (`INTERVAL 365 DAY` в подзапросе `r`) вместо периода дашборда —
   продажи уже используют `@DS_START_DATE`/`@DS_END_DATE` (`WHERE` верхнего уровня), возвраты нет.
2. Размножение суммы возвратов по разрезу строки: `r.return_sum_kgs` агрегирован ТОЛЬКО по `agent_id`,
   но строка результата разрезана дополнительно по `sales_channel_name`/`project_name` (оба поля есть в
   `GROUP BY`). У одного контрагента, продающего через несколько каналов/проектов, одна и та же сумма
   возвратов повторяется в каждой такой строке — суммирование `return_sum_kgs` по контрагенту на
   дашборде даёт кратный (не однократный) итог.
3. Поле `transaction_date` несёт `COUNT(DISTINCT f.transaction_date)` — счётчик дней, а не дату; имя
   вводит в заблуждение.
4. `counterparty_count` — литерал `1`, не считает ничего; при суммировании по любому более широкому
   разрезу (например по стране) наследует ту же проблему кратности, что и п.2: один контрагент,
   размноженный по каналам/проектам, даёт при суммировании `counterparty_count` число строк, а не число
   контрагентов.

**Установленный факт о корне всех четырёх дефектов** (вывод из схемы, не решение архитектора):
`core.fact_returns` (`02_ERP_CONTRACTS.md:88-101`) не несёт ни `sales_channel_id`/`sales_channel_name`,
ни `project_id`/`project_name` — возврат в источнике не имеет разреза по каналу/проекту продажи. Поэтому
дефекты 2 и 4 не чинятся распределением суммы возвратов по каналам/проектам (в данных для этого нет
основания — было бы подстановкой правдоподобного значения, запрещено `★ Anti-improvisation`,
`CLAUDE.md`/`05_CONVENTIONS.md`). Единственная форма, не требующая выдумывания: зерно строки результата
не должно быть мельче зерна, в котором существует сумма возвратов, то есть разрез по
`sales_channel_name`/`project_name` из этого запроса убирается — итоговое зерно строки становится
«один контрагент за период» (совпадает с именем запроса `msklad_counterparty_returns`).

## Шаги
1. Переформулировать задачу своими словами, перечислить входы (ритуал старта, `CLAUDE.md`/`05_CONVENTIONS.md`).
2. Переписать `reference/sql/msklad_counterparty_returns.sql`:
   - убрать `sales_channel_name`/`project_name` из `SELECT` и `GROUP BY` (обоснование — «Входы» выше);
     зерно строки — один контрагент (`agent_id`) за период дашборда;
   - подзапрос `r` (возвраты): период — `@DS_START_DATE`/`@DS_END_DATE` тем же способом, что и продажи
     (`return_date BETWEEN PARSE_DATE('%Y%m%d', @DS_START_DATE) AND PARSE_DATE('%Y%m%d', @DS_END_DATE)`),
     литерал `INTERVAL 365 DAY` убрать;
   - переименовать поле `transaction_date` (сейчас — счётчик дней) в имя, отражающее смысл
     (`EN snake_case`, инвариант `05_CONVENTIONS.md §Часть II`; пример: `active_days_count` — предложение,
     не императив, финальное имя — на усмотрение исполнителя, назвать выбор в SESSION_LOG);
   - `counterparty_count`: заменить литерал `1` на выражение, которое после снятия разреза по
     каналу/проекту (шаг выше) корректно суммируется на дашборде до реального числа контрагентов
     (при зерне «один контрагент на строку» это `COUNT(DISTINCT f.agent_id)` в самой строке — тождественно
     `1`, но семантически верно и не требует ретрофикса при будущем изменении зерна выше по дашборду);
   - список колонок остаётся явным (`ADR-087 §7`), `SELECT *` не вносить;
   - сохранить шапку файла-снимка (комментарии `-- FILE:`, источник, страница дашборда) и обновить
     комментарий о дефекте периода/зерна на факт «исправлено этой задачей, приёмка `ADR-085 §10`».
3. Сверить итоговый текст с приёмкой ниже построчно.
4. Явно назвать в session-блоке видимое следствие для владельца: страница «Операционка» лишается
   разреза по каналу/проекту продаж В ЭТОМ ИМЕННО запросе (данные для такого разреза возвратов не
   существуют) — владелец видит это при вставке текста и read-back (`ADR-085 §9`), решение о том, нужен
   ли отдельный источник с разрезом без возвратов, остаётся за ним и вне scope этой задачи.

## Критерии приёмки (Acceptance)
Дословно `ADR-085 §10`:
- возвраты берутся в границах периода дашборда и в том же зерне, что строка результата;
- сумма возвратов по странице совпадает с прямым запросом к `core.fact_returns` за тот же период;
- поле `transaction_date` переименовано по смыслу (счётчик дней);
- `counterparty_count` перестаёт быть константой.

Дополнительно (не новое условие, следствие уже принятых правил):
- список колонок остаётся явным, `SELECT *` не вносится (`ADR-087 §7`);
- возвраты используют `@DS_START_DATE`/`@DS_END_DATE` тем же способом, что продажи (`ADR-087 §1`,
  без литерального скользящего окна, `ADR-087 §3`).

## Что вернуть человеку (Return-this)
- Полный новый текст `reference/sql/msklad_counterparty_returns.sql`, готовый для вставки владельцем в
  Looker Studio (сама вставка — класс B, владелец, `ADR-085 §9`/`ADR-091 §3`).
- В session-блоке — явное однострочное предупреждение владельцу о снятии разреза
  по каналу/проекту (см. Шаг 4), без внутренних идентификаторов в самой прозе к владельцу (`ADR-056`).

## Вне scope этой задачи
- Вставка текста в интерфейс Looker Studio и read-back — владелец (`ADR-085 §9`).
- Исправление зоны времени `core.fact_returns.return_date` (`INGEST-MOMENT-ZONE-FIX`, гейтится `Q-92`) —
  отдельная задача, класс B, деплой.
- Правка `fact_returns` (курс, период) — отдельная задача `LS-RETURNS-FX-HARDCODE`.
- Объявление исключений периода для других Custom Query — отдельная задача `LS-PERIOD-CONTRACT`.
- Любой источник, кроме `reference/sql/msklad_counterparty_returns.sql`.

## В конце сессии
Выдай SESSION-блок по формату `05_CONVENTIONS` Часть III
(`SESSION_LOG` / `STATE_PATCH` / `NEW_DECISIONS` / `NEW_CONVENTIONS`), файлом в `reference/_inbox/`.
