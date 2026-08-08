# INGEST-MOMENT-ZONE-FIX — подготовка патча (2026-08-08)

**Задача:** `INGEST-MOMENT-ZONE-FIX`, подготовка (класс A, мандат постоянный, гейт `Q-92` снят
`ADR-101 §6`). Три места ингеста берут UTC-время документа МойСклада и объявляют его местным
(Asia/Bishkek) без пересчёта (`Q-77`/`ADR-088 §4`) — патч подготовлен и НЕ задеплоен.

## Шаг 1 — подтверждение дефекта построчно (снапшот на старт сессии)

Снапшот проверен заново по факту старта сессии; последний коммит, трогавший эти файлы —
`025d599e8c210b9566f102d1599ea66b7e3b95eb` (родитель ветки, `e180ed3`). Расхождений с брифом не
найдено.

### `reference/code/cf-facts/fetch_returns.py:115-122` (до патча)

```python
def _parse_moment_kgt(moment_str: str) -> str:
    """
    Парсит moment МойСклада ('2026-01-15 14:30:00.000') в DATE строку по KGT (UTC+6).
    Возвращает 'YYYY-MM-DD'.
    МойСклад отдаёт время в UTC+6 (Asia/Bishkek) без явного offset → прямой парсинг.
    """
    # moment формат: '2026-01-15 14:30:00.000'
    return moment_str[:10]  # берём только дату — время уже в KGT
```

### `reference/code/cf-facts/fetch_purchases.py:41-50` (до патча)

```python
def _parse_date_kgt(moment_str: str) -> Optional[str]:
    """
    Parse МойСклад moment string to DATE (KGT timezone).
    Input:  "2025-10-31 08:16:00.000"
    Output: "2025-10-31"
    МойСклад stores moments in KGT (UTC+6), so no timezone conversion needed.
    """
    if not moment_str:
        return None
    return moment_str[:10]
```

### `reference/sql/sq_marts_expenses.sql:20,44` (до патча)

```sql
-- строка 20
    CAST(l.moment AS DATE)                      AS moment,
-- строка 44
    CAST(c.moment AS DATE)       AS moment,
```

Все три места — ровно там, где называет `ADR-088 §4` (первые два — прямо в `cf-facts`; третье —
уточнение брифа: несущий CF расходной ветки называется `cf-loss-commission`, не `cf-finance`,
и сам ингест дефекта не содержит — `moment` там грузится как полный `TIMESTAMP`; дефект живёт в
`sq_marts_expenses.sql`, куда этот `TIMESTAMP` попадает уже после `MERGE`).

## Шаг 2 — патч `cf-facts` (Python)

Формула вынесена одной функцией в `reference/code/cf-facts/helpers.py`
(`parse_moment_to_bishkek_date`) и импортирована в оба файла — решение по входу «не обязательно,
но снимает риск дублирования» (шаг 2 брифа).

Дифф — см. `reference/_scratch_INGEST-MOMENT-ZONE-FIX_2026-08-08/diff_step2.patch` (тот же текст
приведён ниже целиком).

```diff
--- a/reference/code/cf-facts/helpers.py
+++ b/reference/code/cf-facts/helpers.py
@@
-from datetime import datetime, timezone
+from datetime import datetime, timedelta, timezone
@@
 def run_ts() -> str:
     """Compact timestamp string for run_id / file names: YYYYMMDDTHHMMSS."""
     return datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S")
+
+
+def parse_moment_to_bishkek_date(moment_str: str) -> str:
+    """
+    Парсит moment МойСклада (UTC, '2026-01-15 14:30:00.000') в DATE-строку
+    по Asia/Bishkek (UTC+6). Возвращает 'YYYY-MM-DD'.
+    До фикса (Q-77 / ADR-088 §4): брались первые 10 символов строки — UTC-дата
+    трактовалась как уже местная.
+    """
+    dt_utc = datetime.strptime(moment_str[:19], "%Y-%m-%d %H:%M:%S")
+    return (dt_utc + timedelta(hours=6)).strftime("%Y-%m-%d")

--- a/reference/code/cf-facts/fetch_returns.py
+++ b/reference/code/cf-facts/fetch_returns.py
@@
-from helpers import get_token, paginate_entity, parse_href
+from helpers import get_token, paginate_entity, parse_href, parse_moment_to_bishkek_date
@@
 def _parse_moment_kgt(moment_str: str) -> str:
     """
-    Парсит moment МойСклада ('2026-01-15 14:30:00.000') в DATE строку по KGT (UTC+6).
-    Возвращает 'YYYY-MM-DD'.
-    МойСклад отдаёт время в UTC+6 (Asia/Bishkek) без явного offset → прямой парсинг.
+    Парсит moment МойСклада ('2026-01-15 14:30:00.000') в DATE строку по Asia/Bishkek.
+    Возвращает 'YYYY-MM-DD'. МойСклад отдаёт время в UTC (ADR-088 §1) — конвертация +6ч.
     """
-    # moment формат: '2026-01-15 14:30:00.000'
-    return moment_str[:10]  # берём только дату — время уже в KGT
+    return parse_moment_to_bishkek_date(moment_str)

--- a/reference/code/cf-facts/fetch_purchases.py
+++ b/reference/code/cf-facts/fetch_purchases.py
@@
-from helpers import now_utc_str, paginate_entity, parse_href
+from helpers import now_utc_str, paginate_entity, parse_href, parse_moment_to_bishkek_date
@@
 def _parse_date_kgt(moment_str: str) -> Optional[str]:
     """
-    Parse МойСклад moment string to DATE (KGT timezone).
-    Input:  "2025-10-31 08:16:00.000"
-    Output: "2025-10-31"
-    МойСклад stores moments in KGT (UTC+6), so no timezone conversion needed.
+    Parse МойСклад moment string to DATE by Asia/Bishkek.
+    Input:  "2025-10-31 08:16:00.000" (UTC, ADR-088 §1)
+    Output: "2025-10-31" (UTC+6 conversion)
     """
     if not moment_str:
         return None
-    return moment_str[:10]
+    return parse_moment_to_bishkek_date(moment_str)
```

### Числовая проверка формулы (`★ критерий приёмки выводится из формулы`, `ADR-075 §3`)

Документ `entity/salesreturn` №00008 (`ADR-088 §Контекст`), API `moment = "2026-07-01 15:33:00.000"`:

| | старая формула (`[:10]`) | новая формула (`+6ч`) |
|---|---|---|
| результат | `2026-07-01` | `2026-07-01` |

UTC `15:33` + 6ч = `21:33` того же дня → дата не меняется на этом документе. Обе формулы дают
`2026-07-01`, как и требует приёмка брифа.

**Проверка перехода через полночь** (обязательна отдельно — иначе проверка выше ничего не
доказывает, поскольку совпадает по случайности документа):

| `moment` (UTC) | старая формула | новая формула | различаются? |
|---|---|---|---|
| `2026-07-01 20:15:00.000` | `2026-07-01` | `2026-07-02` | да |
| `2026-07-01 23:59:00.000` | `2026-07-01` | `2026-07-02` | да |

Расчёт (Python, воспроизводимо):
```
dt_utc = datetime.strptime("2026-07-01 20:15:00", "%Y-%m-%d %H:%M:%S")
(dt_utc + timedelta(hours=6)).strftime("%Y-%m-%d")  # -> '2026-07-02'
```
Старая и новая формулы дают разные даты на полосе `UTC [18:00; 24:00)` — ровно та полоса, что
называет `ADR-088 §5` для возвратов/закупок. Формула ведёт себя как ожидается.

## Шаг 3 — патч `sq_marts_expenses.sql`

```diff
--- a/reference/sql/sq_marts_expenses.sql
+++ b/reference/sql/sq_marts_expenses.sql
@@
-    CAST(l.moment AS DATE)                      AS moment,
+    DATE(l.moment, 'Asia/Bishkek')               AS moment,
@@
-    CAST(c.moment AS DATE)       AS moment,
+    DATE(c.moment, 'Asia/Bishkek') AS moment,
```

`l.moment`/`c.moment` уже `TIMESTAMP` в `core.fact_loss`/`core.fact_commissionreportin`
(`LOSS_SCHEMA`/`COMM_SCHEMA`, шаг 1 брифа, вход 2) — `PARSE_TIMESTAMP` не требуется, `DATE(<ts>,
<tz>)` достаточно. `p.moment` (`core.fact_payments`, ветка `src` строки 2-14) не тронут — вне scope
(вход 3 брифа). Остальной файл (`DATE_TRUNC`/`EXTRACT`/`FORMAT_DATE` на `s.moment`, строки 60-63,
и весь `SELECT` ниже `src`) побайтово идентичен — `git diff` показывает ровно две изменённые строки
(см. `reference/_scratch_INGEST-MOMENT-ZONE-FIX_2026-08-08/git_diff_sql.txt`).

## Шаг 4 — сплошной поиск того же паттерна

Команда: `grep -rn 'moment.*\[:10\]\|CAST(.*moment.*AS DATE)' reference/code/ reference/sql/`

```
reference/code/cf-finance/main.py:58:                    "moment": row.get("moment")[:10] if row.get("moment") else None,
reference/code/cf-finance/invoices.py:292:    -- НЕ moment_raw[:10] — это дефект четырёх существующих веток ингеста.
reference/code/cf-facts/fetch_perimeter.py:24:не `moment_str[:10]`.
reference/sql/sq_marts_expenses_pre_fx_policy_2026-07-28.sql:26:    CAST(l.moment AS DATE)                      AS moment,
reference/sql/sq_marts_expenses_pre_fx_policy_2026-07-28.sql:50:    CAST(c.moment AS DATE)       AS moment,
```

Решение по каждому совпадению (`★ Успех инструмента ≠ факт` не применим здесь — выдача непустая,
но каждое совпадение разбирается явно, не молчанием):

1. **`cf-finance/main.py:58`** — `core.fact_payments.moment` (paymentout/cashout). **Вне scope этого
   брифа** (вход 3: правило суток для этой ветки не устанавливается здесь, отдельная задача).
2. **`cf-finance/invoices.py:292`** — не код, комментарий, ПРЕДУПРЕЖДАЮЩИЙ против наивного среза и
   указывающий на уже корректный паттерн строкой ниже (`DATE(PARSE_TIMESTAMP(...), 'Asia/Bishkek')`).
   **Не адресуется** — не дефект, документация корректного паттерна.
3. **`cf-facts/fetch_perimeter.py:24`** — тоже комментарий, ссылается на корректный паттерн
   `bq_ops.py::_PERIMETER_PARSE_DATE`. **Не адресуется** — не дефект.
4. **`reference/sql/sq_marts_expenses_pre_fx_policy_2026-07-28.sql:26,50`** — датированный
   исторический снапшот (до cutover `E1-T1-MECH-FX`, `9465294`), не живой SQL. Провенанс-артефакты
   прошлых состояний не редактируются задним числом. **Не адресуется** — архивный снимок.

Новых находок сверх трёх мест шага 1 нет.

## Что проверено и НЕ сделано (вне scope, по входам брифа)

- Ничего не задеплоено: `gcloud functions deploy` не вызывался, `transferConfig`
  `6a22a243-0000-20fd-a458-883d24f4cad4` не менялся, `git push` в код-репо CF не выполнялся.
- `core.fact_payments.moment` (`cf-finance/main.py:58`) не тронут (вход 3).
- Окно запроса к API (`date_from`/`date_to`) не тронуто (вход 4, `Q-93`).
- `C1`/`C2` (`ADR-030`/`ADR-101 §7`) не затронуты: патч не создаёт и не трогает `MERGE`
  (`_merge_loss`/`_merge_commission` в `cf-loss-commission/main.py`, `bq_ops.py` — не читались на
  предмет правки, только `sq_marts_expenses.sql`, который не содержит `MERGE`).
- Структурное изменение схемы `core.fact_returns`/`core.fact_purchases` (raw `TIMESTAMP` вместо
  `DATE`) не сделано (вход 5) — форма фикса сохраняет тип столбца `DATE` на выходе Python-функции.

## Текст-кандидат `NEW_DECISIONS` (proposed) — см. session-блок

Текст-кандидат для правки `02_ERP_CONTRACTS.md` вынесен в session-блок
(`reference/_inbox/session_INGEST-MOMENT-ZONE-FIX_2026-08-08.md`), `06` append-only, сама задача
STABLE-документ не правит.
