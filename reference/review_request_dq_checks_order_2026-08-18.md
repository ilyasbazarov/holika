# FILE: review_request_dq_checks_order_2026-08-18.md

# Запрос ревью — DQ-FRESHNESS-WIRE, шаг (2): повторное ревью с факт-проверкой исполнением

**Предмет:** шаг (2) остатка `ADR-186 §6` — повторное ревью архитектора патча шага (1)
(`DQ-FRESHNESS-WIRE-CHECKS-ORDER`, 2026-08-18) с факт-проверкой исполнением, гейт на
выдачу нового мандата класса B (шаг 3, деплой).

**База:** `14bc380ed5f26382b21621ce6bd430506720c542` (основное дерево после ноги 3, сборка
буфера 2026-08-18, восьмой проход).

## Что изменено

Файл: `reference/code/cf-dq/main.py`. Было: блок `CHECKS = [...]` (19 пар) на строках
`215-235`, ВЫШЕ определений двенадцати функций `check_freshness_*` (`270-511`) — источник
`NameError` при импорте, сорвавшего попытку деплоя `2026-08-18`. Стало: блок `CHECKS` на
строках `489-509`, между концом `check_freshness_invoices_business` (строка `477-487`) и
`@functions_framework.http` / `def main(request):` (строки `511-512`). Ни одна строка внутри
блока и ни одна функция не изменены — единственная дополнительная правка: снятие одной лишней
пустой строки на месте старого блока (форматирование).

Полный `git diff` коммита `25f18cc` (та же правка, что вошла в `main` слиянием):

```diff
diff --git a/reference/code/cf-dq/main.py b/reference/code/cf-dq/main.py
index 785241b..737bf60 100644
--- a/reference/code/cf-dq/main.py
+++ b/reference/code/cf-dq/main.py
@@ -212,28 +212,6 @@ def check_currency_normalization(bq):
     """) or 0.0
     return float(avg_rev) < DQ_CURRENCY_MAX_AVG_REV, f"avg_revenue_kgs={float(avg_rev):.2f}"
 
-CHECKS = [
-    ("not_empty",              check_not_empty),
-    ("drift_check",            check_drift),
-    ("drift_zero_docs",        check_drift_zero_docs),
-    ("fk_integrity",           check_fk_integrity),
-    ("freshness",              check_freshness),
-    ("margin_sanity",          check_margin_sanity),
-    ("currency_normalization", check_currency_normalization),
-    ("freshness_purchases_technical",         check_freshness_purchases_technical),
-    ("freshness_purchases_business",          check_freshness_purchases_business),
-    ("freshness_returns_technical",           check_freshness_returns_technical),
-    ("freshness_returns_business",            check_freshness_returns_business),
-    ("freshness_inventory_technical",         check_freshness_inventory_technical),
-    ("freshness_inventory_business",          check_freshness_inventory_business),
-    ("freshness_payments_technical",          check_freshness_payments_technical),
-    ("freshness_payments_business",           check_freshness_payments_business),
-    ("freshness_commissionreportin_technical", check_freshness_commissionreportin_technical),
-    ("freshness_commissionreportin_business", check_freshness_commissionreportin_business),
-    ("freshness_invoices_technical",          check_freshness_invoices_technical),
-    ("freshness_invoices_business",           check_freshness_invoices_business),
-]
-
 # ═══════════════════════════════════════════════════════════════════════════
 # DQ-FRESHNESS-COVERAGE (подготовка, класс A, 2026-08-09 + остаток 2026-08-12)
 # — проверки свежести для шести таблиц ядра без наблюдателя. ПОДКЛЮЧЕНЫ к
@@ -508,6 +486,28 @@ def check_freshness_invoices_business(bq):
     except Exception as e:
         return True, f"EXCEPTION (notify-only, не блокирует): {e}"
 
+CHECKS = [
+    ("not_empty",              check_not_empty),
+    ("drift_check",            check_drift),
+    ("drift_zero_docs",        check_drift_zero_docs),
+    ("fk_integrity",           check_fk_integrity),
+    ("freshness",              check_freshness),
+    ("margin_sanity",          check_margin_sanity),
+    ("currency_normalization", check_currency_normalization),
+    ("freshness_purchases_technical",         check_freshness_purchases_technical),
+    ("freshness_purchases_business",          check_freshness_purchases_business),
+    ("freshness_returns_technical",           check_freshness_returns_technical),
+    ("freshness_returns_business",            check_freshness_returns_business),
+    ("freshness_inventory_technical",         check_freshness_inventory_technical),
+    ("freshness_inventory_business",          check_freshness_inventory_business),
+    ("freshness_payments_technical",          check_freshness_payments_technical),
+    ("freshness_payments_business",           check_freshness_payments_business),
+    ("freshness_commissionreportin_technical", check_freshness_commissionreportin_technical),
+    ("freshness_commissionreportin_business", check_freshness_commissionreportin_business),
+    ("freshness_invoices_technical",          check_freshness_invoices_technical),
+    ("freshness_invoices_business",           check_freshness_invoices_business),
+]
+
 @functions_framework.http
 def main(request):
     body   = request.get_json(silent=True) or {}
```

## Факт-проверка

Команда (дословно, `reference/_scratch_DQ-FRESHNESS-WIRE-CHECKS-ORDER_2026-08-18/import_check.py`,
прогнана из каталога ветки деплоя `worktrees/DQ-FRESHNESS-WIRE-CHECKS-ORDER`):

```
/opt/homebrew/opt/python@3.14/bin/python3.14 import_check_variant.py reference/code/cf-dq
```

(целевой прогон, ограниченный модулем `main`, см. `import_check_main_run.log`; универсальный
прогон по всем `.py` каталога — `import_check_run.log`).

**Версия интерпретатора:** `3.14.6 (main, Jun 10 2026, 10:03:53) [Clang 17.0.0
(clang-1700.6.4.2)]` (Homebrew, `/opt/homebrew/opt/python@3.14/bin/python3.14`).

**Отклонение, названное явно:** системный `python3` дерева/машины — `3.9.6`
(`/Library/Developer/CommandLineTools/usr/bin/python3`) — не тянет аннотацию `dict | None`
(PEP 604) в `helpers.py`/`main.py`: `TypeError: unsupported operand type(s) for |: 'type' and
'NoneType'` на обоих модулях, воспроизводится одинаково ДО и ПОСЛЕ переноса `CHECKS` —
свойство МАШИНЫ (версии интерпретатора), не патча. Проверка повторена на альтернативном
интерпретаторе той же машины (`python@3.14`), результат ниже.

**Вывод (`import_check_main_run.log`):**

```
интерпретатор: 3.14.6 (main, Jun 10 2026, 10:03:53) [Clang 17.0.0 (clang-1700.6.4.2)]
ok   импорт main
len(CHECKS)=19
```

`rc=0`. `len(CHECKS)=19`.

Сторонние зависимости (`google.cloud.bigquery`, `functions_framework`) — снисходительные
стабы (`__getattr__` возвращает вызываемый объект), форма — `import_check.py` из прецедента
`reference/_scratch_SALES-REFRESH-WINDOW-GUARD-FIX-DEPLOY-2_2026-08-18/`; `functions_framework.http`
переопределён identity-декоратором явно (обязан вернуть саму функцию `main`).

`patch_dq.py` (четвёртый `.py` файл каталога `cf-dq/`) в целевую проверку не входит:
одноразовый локальный скрипт правки, читающий `main.py` по относительному пути от CWD
(`open("main.py")`), не импортируется `main.py`, не декорирован `functions_framework.http`,
не часть графа исполнения CF, не деплоится. Первый (универсальный) прогон корректно поймал
его как `FileNotFoundError` — свойство скрипта, не дефект патча.

## Четыре пункта приёмки — по каждому факт

1. **Блок `CHECKS` ниже `check_freshness_invoices_business`, выше `def main(request)`.**
   Факт: `check_freshness_invoices_business` — строки `477-487`; `CHECKS = [` — строка `489`;
   закрывающая `]` — строка `509`; `def main(request):` — строка `512`. Порядок соблюдён.
2. **Импорт из каталога ветки, `rc=0`, `len(CHECKS)=19`.** Факт: см. вывод выше,
   `import_check_main_run.log`, прогон на `python 3.14.6` из каталога
   `worktrees/DQ-FRESHNESS-WIRE-CHECKS-ORDER/reference/code/cf-dq`.
3. **`git diff` — ровно один файл, ровно перемещение блока.** Факт: `git show 25f18cc --stat`
   — `reference/code/cf-dq/main.py | 44 ++++++++++++++++++++++----------------------`, один
   файл; полный diff (выше) показывает удалённый и добавленный блок `CHECKS` побайтово
   идентичными по 19 строкам содержимого, ни одна функция не тронута.
4. **Логи файлами.** Факт: `reference/_scratch_DQ-FRESHNESS-WIRE-CHECKS-ORDER_2026-08-18/` —
   `import_check.py`, `import_check_run.log`, `import_check_main_run.log`, `git_diff_stat.log`,
   `git_diff_full.log`.

## Адреса логов

- `reference/_scratch_DQ-FRESHNESS-WIRE-CHECKS-ORDER_2026-08-18/import_check.py`
- `reference/_scratch_DQ-FRESHNESS-WIRE-CHECKS-ORDER_2026-08-18/import_check_run.log`
- `reference/_scratch_DQ-FRESHNESS-WIRE-CHECKS-ORDER_2026-08-18/import_check_main_run.log`
- `reference/_scratch_DQ-FRESHNESS-WIRE-CHECKS-ORDER_2026-08-18/git_diff_stat.log`
- `reference/_scratch_DQ-FRESHNESS-WIRE-CHECKS-ORDER_2026-08-18/git_diff_full.log`
- `reference/dq_freshness_wire_checks_order_2026-08-18.md` (полный отчёт исполнителя)

## Что НЕ делалось

Деплой; любые живые вызовы `gcloud`/`bq`; правка `config.py`, `helpers.py` или порогов; любые
другие правки `main.py`; слияние веток код-репо; `master` код-репо. Новых строк реестра
работа не завела (`ADR-186 §6`, `ADR-156 §2/§5`) — доисполнила существующую строку
`DQ-FRESHNESS-WIRE`, шаг (1) из трёх.

## Отдельная находка, не входящая в предмет ревью

Машина исполнения несёт два интерпретатора `python3` с разным поведением на PEP 604 —
зафиксировано `07_STATE.md §Подробности для модели` как факт для будущих факт-проверок
исполнением; решения не требует.
