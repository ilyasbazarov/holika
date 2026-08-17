# FILE: dq_freshness_wire_guard_fix_2026-08-17.md

# `DQ-FRESHNESS-WIRE-GUARD-FIX` — перенос формы try/except на шесть `*_business`-проверок

**Задача:** `DQ-FRESHNESS-WIRE-GUARD-FIX` (класс A, мандат постоянный, без брифа — `ADR-086 §1`).
**База:** `b1ededa`. **Дата:** 2026-08-17 (Бишкек).
**Повод:** `reference/dq_freshness_wire_deploy_review_2026-08-17.md` — вердикт НЕ ГОТОВ, дефект
§2: шесть проверок `check_freshness_*_business` не несли `try/except` и структурно МОГЛИ
провалить весь DQ Gate при исключении BigQuery, вопреки заявленной наблюдающей форме.
**Провенанс:** `reference/_scratch_DQ-FRESHNESS-WIRE-GUARD-FIX_2026-08-17/` (скрипт обхода AST,
лог с UTC-якорем первой и последней строкой; облачных вызовов не было — только чтение локального
кода и программный разбор).

---

## §1. Что сделано

В `reference/code/cf-dq/main.py` шесть функций получили ровно ту форму, что уже стояла на их
парных `*_technical`: тело целиком обёрнуто в `try`, добавлен
`except Exception as e: return True, f"EXCEPTION (notify-only, не блокирует): {e}"` в конце.
Затронутые функции: `check_freshness_purchases_business`, `check_freshness_returns_business`,
`check_freshness_inventory_business`, `check_freshness_payments_business`,
`check_freshness_commissionreportin_business`, `check_freshness_invoices_business`.

Никакой новой логики, порогов или текстов `detail` сверх добавляемой ветки `except` не менялось.
Поведение при успешном запросе не изменилось — SQL, условия и формат `detail` внутри `try`
идентичны исходным.

---

## §2. Приёмка

### (i) Компиляция

```
python3 -m py_compile reference/code/cf-dq/main.py
```
→ `COMPILE_OK` (без исключений).

### (ii) Программный обход всех двенадцати функций свежести

Скрипт `reference/_scratch_DQ-FRESHNESS-WIRE-GUARD-FIX_2026-08-17/check_try_except.py` парсит
`main.py` через `ast`, для каждой из двенадцати функций `check_freshness_*` ищет `Try`-узел с
обработчиком `except Exception`. Полный лог с UTC-якорем —
`reference/_scratch_DQ-FRESHNESS-WIRE-GUARD-FIX_2026-08-17/verify_2026-08-17.log`.

| Функция | `try` | `except Exception` | Может ли заблокировать конвейер |
|---|---|---|---|
| `check_freshness_purchases_technical` | ДА | ДА | нет |
| `check_freshness_purchases_business` | ДА | ДА | нет |
| `check_freshness_returns_technical` | ДА | ДА | нет |
| `check_freshness_returns_business` | ДА | ДА | нет |
| `check_freshness_inventory_technical` | ДА | ДА | нет |
| `check_freshness_inventory_business` | ДА | ДА | нет |
| `check_freshness_payments_technical` | ДА | ДА | нет |
| `check_freshness_payments_business` | ДА | ДА | нет |
| `check_freshness_commissionreportin_technical` | ДА | ДА | нет |
| `check_freshness_commissionreportin_business` | ДА | ДА | нет |
| `check_freshness_invoices_technical` | ДА | ДА | нет |
| `check_freshness_invoices_business` | ДА | ДА | нет |

Итог скрипта: `все двенадцать защищены, блокирующих нет` (`RC=0`).

### (iii) Дифф ограничен объявленным объёмом

`reference/_scratch_DQ-FRESHNESS-WIRE-GUARD-FIX_2026-08-17/main_py.diff` — шесть хунков, по
одному на каждую `*_business`-функцию, ровно форма «обернуть тело в try + добавить except».
Проверено чтением диффа: `check_not_empty`, `check_drift`, `check_fk_integrity`,
`check_freshness`, `check_margin_sanity`, `check_currency_normalization`,
`check_drift_zero_docs` и `main()` не встречаются в диффе — не тронуты.

### (iv) Исправлен зависимый текст

`reference/dq_gate_block_bounded_2026-08-17.md §1` нёс утверждение «остальные тринадцать
структурно не могут вернуть `False`», верное на момент своего написания только для семи из
тринадцати (найдено ревью, §2.6). Добавлен абзац «Правка (`DQ-FRESHNESS-WIRE-GUARD-FIX`,
2026-08-17)»: называет период, когда утверждение было неверно для шести `*_business` (с выката
`DQ-FRESHNESS-WIRE` 2026-08-13 до этой правки), ссылается на источник дефекта (ревью) и на
провенанс подтверждения (§2 (ii) выше). После правки утверждение верно для всех тринадцати без
исключения — существующий текст §1 не переписан, дополнен.

---

## §3. Что не делалось (запреты соблюдены)

- Деплой `cf-dq` не производился (класс B, мандат не выдан — вне объёма этой задачи).
- `main()` не изменён — внешний `except` там остаётся последней линией для шести блокирующих
  проверок.
- Шесть блокирующих проверок (`not_empty`, `drift_check`, `fk_integrity`, `freshness`,
  `margin_sanity`, `currency_normalization`) и `check_drift_zero_docs` не тронуты.
- `helpers.py` не менялся.
- Пороги и тексты `detail` вне добавляемой ветки `except` не менялись.

---

## §4. Следующий шаг

Повторное ревью архитектора (`reference/dq_freshness_wire_deploy_review_2026-08-17.md §6` п.2) —
гейт перед запросом мандата класса B на деплой `cf-dq` (п.3-4 того же §6).
