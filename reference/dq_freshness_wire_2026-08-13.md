# FILE: dq_freshness_wire_2026-08-13.md

# DQ-FRESHNESS-WIRE — подключение двенадцати проверок свежести к `CHECKS`

**Задача:** `DQ-FRESHNESS-WIRE` (класс A, без брифа, `ADR-086 §1`; строка задачи заведена коммитом
`47e6511`, `07_GAPS.md` + `07_STATE.md §Открытые вопросы`/`§Мандат Claude Code`).
**Дата:** 2026-08-13. **Исполнитель:** сессия `DQ-FRESHNESS-WIRE` (рабочее дерево
`worktrees/DQ-FRESHNESS-COVERAGE`, ветка `s/DQ-FRESHNESS-COVERAGE`).

## Предмет

Задача `DQ-FRESHNESS-COVERAGE` закрыта DONE (`07_ARCHIVE.md`, 2026-08-13, сессия `DQ-CFDQ-DEPLOY`) —
двенадцать функций свежести (шесть таблиц ядра × A/B) написаны и лежат в снапшоте
`reference/code/cf-dq/main.py`, задеплоены живой ревизией `cf-dq-00009-coy`. Эта сессия НЕ
переоткрывает то решение: предмет здесь другой — эти двенадцать функций были задеплоены, но НЕ входили
в список `CHECKS`, который перебирает `main()` (`main.py:429` цикл `for name, fn in CHECKS`), и потому
физически не исполнялись. Живой прогон `run_id=1786564802.7168841` (см. `07_GAPS.md` строка
`DQ-FRESHNESS-WIRE`) записал ровно семь имён проверок — шесть таблиц ядра оставались без наблюдателя
несмотря на задеплоенный код.

## Факт до правки (подтверждён грепом на базе коммита до правки, `680de46`→`47e6511`)

```
CHECKS = [
    ("not_empty",              check_not_empty),
    ("drift_check",            check_drift),
    ("drift_zero_docs",        check_drift_zero_docs),
    ("fk_integrity",           check_fk_integrity),
    ("freshness",              check_freshness),
    ("margin_sanity",          check_margin_sanity),
    ("currency_normalization", check_currency_normalization),
]
```

Семь пар. Ни одной из двенадцати функций `check_freshness_{purchases,returns,inventory,payments,
commissionreportin,invoices}_{technical,business}` (`main.py:251-424` на старой нумерации) в списке
нет.

## Форма подключения — НАБЛЮДАЮЩАЯ, не блокирующая

Шесть проверок (B) (бизнес-диагностика) уже возвращали `passed=True` всегда по своей исходной
конструкции (`reference/dq_freshness_coverage_2026-08-09.md`, `reference/invoices_loader_design_2026-08-02.md
§9.2`) — подключены к `CHECKS` как есть, без правки тела функции.

Шесть проверок (A) (техническая свежесть по `_loaded_at`) ДО этой сессии могли структурно вернуть
`passed=False` (превышение порога или `NULL` при пустой таблице) — то есть были блокирующими ПО ФОРМЕ.
Подключение их в исходном виде к `CHECKS` немедленно сделало бы DQ Gate блокирующимся по шести новым
условиям одновременно с передачей клиенту — тот же класс риска, который чинила переделка метрики
дрейфа (`ADR-153`/`ADR-173`, драйвер: DQ Gate — единый выключатель всего конвейера, один неверный
блок валит весь прогон промоута).

Поэтому каждая из шести технических функций переписана в наблюдающую форму по прецеденту
`check_drift_zero_docs` (`main.py`, `ADR-153` кандидат 1, ревью `ADR-173`): весь запрос обёрнут в
`try/except`, любой исход (успех, `NULL`, исключение BQ) уходит в `return True, detail` — функция
СТРУКТУРНО не может вернуть `False`. Порог и результат сравнения не теряются — они печатаются в
`detail` строкой вида `lag=<N>, threshold=<M>, VERDICT=OK|EXCEEDED`, доступной через `audit.dq_runs`
(колонка `detail`, `helpers.write_dq_results`).

### Пример (до/после), `check_freshness_purchases_technical`

**До** (блокирующая по форме):
```python
def check_freshness_purchases_technical(bq):
    row = run_row(bq, f"""...""")
    if not row or row.get("load_lag_hours") is None:
        return False, "load_lag_hours=NULL (таблица пустая)"
    lag = row["load_lag_hours"]
    return (lag <= DQ_FRESHNESS_PURCHASES_MAX_HOURS,
            f"load_lag_hours={lag}, distinct_load_stamps={row['distinct_load_stamps']}, n_rows={row['n_rows']}")
```

**После** (наблюдающая, не может вернуть `False`):
```python
def check_freshness_purchases_technical(bq):
    try:
        row = run_row(bq, f"""...""")
        if not row or row.get("load_lag_hours") is None:
            return True, (f"lag=NULL (таблица пустая), threshold={DQ_FRESHNESS_PURCHASES_MAX_HOURS}, "
                           f"VERDICT=UNKNOWN (notify, не блокирует)")
        lag = row["load_lag_hours"]
        verdict = "OK" if lag <= DQ_FRESHNESS_PURCHASES_MAX_HOURS else "EXCEEDED"
        return True, (f"lag={lag}, threshold={DQ_FRESHNESS_PURCHASES_MAX_HOURS}, VERDICT={verdict}, "
                       f"distinct_load_stamps={row['distinct_load_stamps']}, n_rows={row['n_rows']} "
                       f"(notify, не блокирует)")
    except Exception as e:
        return True, f"EXCEPTION (notify-only, не блокирует): {e}"
```

Та же трансформация применена к `check_freshness_returns_technical`,
`check_freshness_inventory_technical`, `check_freshness_payments_technical`,
`check_freshness_commissionreportin_technical`, `check_freshness_invoices_technical` — построчный
стамп `_loaded_at` у `fact_payments`/`fact_commissionreportin` остаётся снят с критического пути тем
же основанием (`ADR-155`), комментарий в коде не тронут.

Полный текст всех шести переписанных функций — в диффе, `reference/_scratch_DQ-FRESHNESS-WIRE_2026-08-13/main_py.diff`.

## Факт после правки

```
CHECKS = [
    ("not_empty",              check_not_empty),
    ("drift_check",            check_drift),
    ("drift_zero_docs",        check_drift_zero_docs),
    ("fk_integrity",           check_fk_integrity),
    ("freshness",              check_freshness),
    ("margin_sanity",          check_margin_sanity),
    ("currency_normalization", check_currency_normalization),
    ("freshness_purchases_technical",          check_freshness_purchases_technical),
    ("freshness_purchases_business",           check_freshness_purchases_business),
    ("freshness_returns_technical",            check_freshness_returns_technical),
    ("freshness_returns_business",             check_freshness_returns_business),
    ("freshness_inventory_technical",          check_freshness_inventory_technical),
    ("freshness_inventory_business",           check_freshness_inventory_business),
    ("freshness_payments_technical",           check_freshness_payments_technical),
    ("freshness_payments_business",            check_freshness_payments_business),
    ("freshness_commissionreportin_technical", check_freshness_commissionreportin_technical),
    ("freshness_commissionreportin_business",  check_freshness_commissionreportin_business),
    ("freshness_invoices_technical",           check_freshness_invoices_technical),
    ("freshness_invoices_business",            check_freshness_invoices_business),
]
```

19 пар (7 старых без изменений + 12 новых). Проверено:

```
awk '/^CHECKS = \[/,/^\]/' reference/code/cf-dq/main.py | grep -c '^\s*("'
→ 19
```

Каждая из двенадцати функций названа поимённо в списке.

## `py_compile`

```
python3 -m py_compile reference/code/cf-dq/main.py
→ rc=0
```
Полный лог — `reference/_scratch_DQ-FRESHNESS-WIRE_2026-08-13/py_compile.log`.

## Подтверждение «не может вернуть False» (греп по шести функциям)

Для каждой из `check_freshness_{purchases,returns,inventory,payments,commissionreportin,
invoices}_technical` — вырезано тело функции до следующего `def`, найдены все `return`:

```
=== check_freshness_purchases_technical ===
return True, (f"lag=NULL ...")
return True, (f"lag={lag}, threshold=... VERDICT={verdict}, ...")
return True, f"EXCEPTION (notify-only, не блокирует): {e}"
```
(тот же список у остальных пяти, только имя порога/таблицы меняется). Ни одного `return False` ни в
одной из шести функций. Полный вывод — `reference/_scratch_DQ-FRESHNESS-WIRE_2026-08-13/no_false_check.log`.

## Что НЕ сделано (вне scope, по строке `07_GAPS.md`)

- Деплой `cf-dq` (`DQ-FRESHNESS-WIRE-DEPLOY`, класс B, мандат НЕ выдан).
- Правка порогов в `reference/code/cf-dq/config.py` — пороги не менялись, взяты как заведены
  `DQ-FRESHNESS-COVERAGE`.
- Любые живые вызовы (`bq query` без `--dry_run`, `gcloud functions deploy`) — не исполнялись.
- Путь сигнала/алертинга: телеграм-алерт завязан на провал гейта и не сработает на наблюдающую форму
  — сигнал живёт только в `audit.dq_runs` (колонка `detail`), запрос к ней — отдельная задача
  `DQ-GATE-BLOCK-BOUNDED` (названо явно строкой `07_GAPS.md`, не переизобретается здесь).

## Файлы

- `reference/code/cf-dq/main.py` — правка (диф целиком в `_scratch`).
- `reference/dq_freshness_wire_2026-08-13.md` — этот файл.
- `reference/_scratch_DQ-FRESHNESS-WIRE_2026-08-13/main_py.diff` — полный дифф.
- `reference/_scratch_DQ-FRESHNESS-WIRE_2026-08-13/py_compile.log` — лог компиляции.
- `reference/_scratch_DQ-FRESHNESS-WIRE_2026-08-13/no_false_check.log` — греп-подтверждение.

## Команда для самостоятельной перепроверки владельцем

```bash
cd reference/code/cf-dq
python3 -m py_compile main.py && echo OK
awk '/^CHECKS = \[/,/^\]/' main.py | grep -c '^\s*("'
```
Ожидаемо: `OK`, затем `19`.
