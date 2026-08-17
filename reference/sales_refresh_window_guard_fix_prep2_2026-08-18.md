# FILE: sales_refresh_window_guard_fix_prep2_2026-08-18.md

# Обвязка `run_started_at` — `SALES-REFRESH-WINDOW-GUARD-FIX-PREP2` (исполнение)

**Сессия:** `SALES-REFRESH-WINDOW-GUARD-FIX-PREP2` (исполнитель, класс A, без брифа — `ADR-086 §1`).
**Дерево/ветка:** `worktrees/SALES-REFRESH-WINDOW-GUARD-FIX-PREP2` / `s/SALES-REFRESH-WINDOW-GUARD-FIX-PREP2`.
**База:** `61e48c17086d9d8d32f6af1710cdd62a7ccec3e0` (`git rev-parse HEAD` на старте сессии).
**Провенанс:** `reference/_scratch_SALES-REFRESH-WINDOW-GUARD-FIX-PREP2_2026-08-18/`
(`verify_promote_chain.py`, `verify_promote_chain.log` — UTC-якорь первой и последней строкой;
облачных вызовов не было — стабы `flask`/`requests`/`tenacity`/`google.cloud.*` в `sys.modules`,
запуск скрипта `python3.14` — на этой машине `python3` резолвится в `3.9.6`, а один из
непатченных файлов `cf-facts` (`fetch_returns.py`) несёт аннотацию `X | None`, требующую
PEP 604, доступного этой машине только через `python3.14`; `py_compile` (приёмка п.4)
прогонялся отдельно системным `python3`).
**Вход:** `reference/guard_fixes_review_2026-08-17.md §3-§7` (находка ревью, приёмка из
шести пунктов), `reference/sales_refresh_window_guard_fix_prep_2026-08-17.md` (первая
подготовка — верхний край предохранителя, «известный сознательный хвост» §2),
`reference/code/cf-facts/bq_ops.py:403-500` + `promote_to_core`/`promote_perimeter_to_core`,
`reference/code/cf-facts/main.py:78-120,238-260,396-410`, `workflow_hourly.yaml`
(шаги `step_facts`/`step_dq`/`step_promote` — не тронуты, `run_id` уже передаётся во все шаги).

---

## 1. Что сделано

`run_started_at` протянут через все три уровня, ни один не пропущен (`§7 п.1`):

```
main()  →  _run_promote(window_days, run_id)          →  promote_to_core(bq, window_days, run_started_at)
           _run_perimeter_promote(window_days, run_id)    promote_perimeter_to_core(bq, window_days, run_started_at)
```

Якорь — `run_id`, уже присутствующий в `main()` (`main.py:82`,
`run_id = body.get("run_id") or run_ts()`), тот же момент старта прогона Workflow, который
первая подготовка (`PREP`) выбрала как единственно рабочий (`sales_refresh_window_guard_fix_
prep_2026-08-17.md §1`). Новая функция `_parse_run_started_at(run_id)` (`main.py`, между
`log = logging.getLogger(__name__)` и точкой входа `main()`) переводит `run_id` в `datetime`
и вызывается внутри `_run_promote`/`_run_perimeter_promote` — то есть только на пути
`promote`/`perimeter_promote`, не на пути загрузки (`hourly`/`weekly`/`perimeter`), где
`run_id` нужен лишь как метка прогона, не как якорь предохранителя.

## 2. Разбор трёх видов `run_id`

`_parse_run_started_at` различает явно (`§7 п.3`):

- **float** (JSON-число `sys.now()` от обоих workflow) → `datetime.fromtimestamp(float(run_id),
  tz=timezone.utc)`.
- **строка-число** того же вида → тот же путь, обёрнутый в `try/except ValueError`.
- **строка `%Y%m%dT%H%M%S`** (`run_ts()`, локальный fallback при вызове без `run_id` в теле) →
  `datetime.strptime(run_id, "%Y%m%dT%H%M%S").replace(tzinfo=timezone.utc)`.
- **всё остальное** (неразбираемая строка, `None`, любой другой тип) → `raise ValueError` с
  текстом, называющим полученное значение и его тип, до какого-либо запроса к BigQuery
  (fail-closed, `ADR-145`).

Побочное следствие, названное заранее и подтверждённое контролем (iii) ниже: прямой ручной
вызов `mode=promote` без `run_id` в теле получает `run_ts()` как строку — она разбирается
третьей веткой и предохранитель работает как обычно; отказывает только вызов с `run_id`,
который не разбирается ни одним из трёх видов (например, `run_id="abc"`, что реалистично
только при испорченном ручном вызове). Ручной вызов `cf-facts` в обход конвейера остаётся
запрещённым путём по отдельной причине (`dq_gate_block_bounded_2026-08-17.md §3`) — этот патч
её не меняет.

## 3. Ни один вызов не остался на старой арности

Машинный обход (счётчик совпадений, не утверждение — `§7 п.2`):

```
$ grep -n "promote_to_core(\|promote_perimeter_to_core(" reference/code/cf-facts/*.py
bq_ops.py:9:  - promote_to_core(): MERGE staging → core.fact_sales_profit
bq_ops.py:501:def promote_to_core(
bq_ops.py:732:def promote_perimeter_to_core(
main.py:285:    merge_stats    = promote_to_core(bq, window_days, run_started_at)
main.py:443:    merge_stats = promote_perimeter_to_core(bq, window_days, run_started_at)

$ grep -n "_run_promote(\|_run_perimeter_promote(" reference/code/cf-facts/*.py
main.py:129:            result = _run_promote(window_days, run_id)
main.py:137:            result = _run_perimeter_promote(window_days, run_id)
main.py:269:def _run_promote(window_days: int, run_id) -> dict:
main.py:432:def _run_perimeter_promote(window_days: int, run_id) -> dict:
```

Оба вызова `promote_to_core`/`promote_perimeter_to_core` (2 совпадения) несут три аргумента;
оба вызова `_run_promote`/`_run_perimeter_promote` из `main()` (2 совпадения) несут `run_id`;
обе сигнатуры функций-обёрток объявляют параметр `run_id`. Совпадений старой (двухаргументной)
формы — `0`.

## 4. `python3 -m py_compile`

```
$ python3 -m py_compile reference/code/cf-facts/main.py reference/code/cf-facts/bq_ops.py
$ echo $?
0
```

## 5. Три контроля на числах инцидента `2026-08-16` — через полную цепочку от `main()`

Скрипт `reference/_scratch_SALES-REFRESH-WINDOW-GUARD-FIX-PREP2_2026-08-18/verify_promote_chain.py`
подставляет фейковые `google.cloud.bigquery`/`storage`/`secretmanager`, `flask`, `requests`,
`tenacity` в `sys.modules` ДО `import main` (эти пакеты не установлены в окружении сессии;
облачных вызовов не было и не требовалось — сравнение дат детерминировано), затем вызывает
**`main.main(fake_request)`** — то есть настоящую точку входа Cloud Function, не
`promote_to_core` напрямую. Фейковый BQ-клиент диспетчеризует по содержимому SQL (`COUNT(*)`
→ `cnt`; запрос предохранителя → `min_date`/`window_start`/`max_loaded_at`; `MERGE` →
`num_dml_affected_rows`; запрос покрытия → агрегаты). Числа — те же, что в первой подготовке
(`run_id=1786842001.2609222` → `2026-08-16T01:00:01.260922Z`, `MAX(_loaded_at)=2026-08-16
01:18:21Z`, `stage3 §3`/`step1_run.log`).

**(i) Позитивный** — `run_id=1786842001.2609222` (float), `mode=promote` И `mode=perimeter_
promote`: `HTTP 200`, `status=ok`, `MERGE complete`.

**(ii) Отрицательный** — тот же `run_id`, `MAX(_loaded_at)` искусственно состарен на 1 час до
начала прогона: `HTTP 500`, ошибка называет `предохранитель ADR-145 §4 (свежесть)`.

**(iii) Разбор форм** — `run_id="20260816T011821"` (строка `run_ts()`) разбирается третьей
веткой и проходит теми же числами (`HTTP 200`); `run_id="abc"` даёт названный отказ
`Неразбираемый run_id='abc' (str) — …` (`HTTP 500`) ДО какого-либо обращения к BQ.

Полный вывод (`date -u` первой и последней строкой) —
`reference/_scratch_SALES-REFRESH-WINDOW-GUARD-FIX-PREP2_2026-08-18/verify_promote_chain.log`.

## 6. Нижний край, `GUARD_TOLERANCE_DAYS`, тела `MERGE` — не изменены

```
$ git diff --stat reference/code/cf-facts/bq_ops.py
(пусто)
```

Дифф этой сессии затрагивает ТОЛЬКО `reference/code/cf-facts/main.py`. `bq_ops.py` не тронут
ни строкой — нижний край предохранителя, `GUARD_TOLERANCE_DAYS` и тела обоих `MERGE`
(`_build_merge_sql`/`_build_perimeter_merge_sql`) остаются точно теми, что оставила первая
подготовка (`PREP`, принята ревью `§2`).

## 7. Приёмка — шесть пунктов дословно (`guard_fixes_review_2026-08-17.md §7`)

1. `run_started_at` протянут через все три уровня — §1.
2. Ни один вызов не остался на старой арности — §3 (машинный обход, счётчик совпадений).
3. Разбор `run_id → datetime` различает все три вида явно; неразбираемое — отказ с названной
   ошибкой — §2, §5(iii).
4. `python3 -m py_compile` по обоим файлам — §4.
5. Три контроля на числах инцидента `2026-08-16`, через полную цепочку от `main()` — §5.
6. Дифф показывает, что нижний край, `GUARD_TOLERANCE_DAYS` и тела обоих `MERGE` не изменены — §6.

## 8. Что этой сессией НЕ делалось

- Не деплоилось — класс B, мандат не выдан.
- `bq_ops.py`, `config.py`, `fetch_perimeter.py`, `helpers.py`, `workflow_hourly.yaml`,
  `workflow_weekly.yaml` — не тронуты.
- Тело предохранителя (`_assert_staging_covers_merge_window`) не переписывалось — принято
  ревью `guard_fixes_review_2026-08-17.md §3`, правится только вызывающая сторона.
- Прямой ручной `mode=promote` без `run_id` после этого патча по-прежнему возможен технически
  (разбирается третьей веткой `run_ts()`), но остаётся запрещённым путём по отдельной причине
  (`dq_gate_block_bounded_2026-08-17.md §3`) — этот патч эту дисциплину не вводит и не снимает,
  только делает предохранитель свежести исполнимым внутри неё, если запрет всё же нарушен.
