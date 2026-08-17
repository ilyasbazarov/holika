"""
Факт-проверка исполнением (05_CONVENTIONS §Процедура деплоя п.9) — попытка реального
импорта модуля cf-dq на СОДЕРЖИМОМ ВЕТКИ ДЕПЛОЯ (worktrees/DQ-FRESHNESS-WIRE-CHECKS-ORDER),
не на снапшоте reference/code/ основного дерева. ast.parse/py_compile не засчитываются
(ловят синтаксис, не NameError уровня модуля).

Внешние зависимости (google.cloud.bigquery, functions_framework) подставляются
снисходительными стабами: любой атрибут — вызываемый объект (__getattr__), любой вызов
возвращает ещё один такой же объект. Форма — reference/_scratch_SALES-REFRESH-WINDOW-GUARD-
FIX-DEPLOY-2_2026-08-18/import_check.py (жёсткие стабы дали ложный провал на
tenacity.before_sleep_log/bigquery.SchemaField в прецеденте GUARD-FIX-PREP2-REVIEW).
"""
import sys
import os
import types
from datetime import datetime, timezone

UTC_START = datetime.now(timezone.utc).isoformat()
print(f"date -u (старт скрипта): {UTC_START}")
print(f"интерпретатор: {sys.version}")
print(f"sys.executable: {sys.executable}")

if len(sys.argv) != 2:
    print("usage: import_check.py <cf-dq-dir>")
    sys.exit(2)

CF_DQ_DIR = os.path.abspath(sys.argv[1])
print(f"каталог проверки (ветка деплоя): {CF_DQ_DIR}")
sys.path.insert(0, CF_DQ_DIR)


class _Permissive:
    """Любой атрибут — вызываемый объект; любой вызов — снова _Permissive."""

    def __getattr__(self, name):
        return _Permissive()

    def __call__(self, *a, **kw):
        return _Permissive()

    def __iter__(self):
        return iter(())

    def __getitem__(self, k):
        return _Permissive()


def _stub_module(name):
    mod = types.ModuleType(name)
    mod.__getattr__ = lambda attr: _Permissive()  # PEP 562, module-level __getattr__
    return mod


for modname in [
    "google", "google.cloud", "google.cloud.bigquery",
    "functions_framework",
]:
    sys.modules[modname] = _stub_module(modname)

sys.modules["google"].cloud = sys.modules["google.cloud"]
sys.modules["google.cloud"].bigquery = sys.modules["google.cloud.bigquery"]

# functions_framework.http используется как декоратор @functions_framework.http —
# снисходительный стаб уже возвращает вызываемый _Permissive на любой атрибут, но
# декоратор обязан вернуть саму функцию (иначе main перестаёт быть функцией и
# последующий код это не поймает); переопределяем .http явным identity-декоратором.
sys.modules["functions_framework"].http = lambda fn: fn

py_modules = sorted(
    f[:-3] for f in os.listdir(CF_DQ_DIR)
    if f.endswith(".py")
)
print(f"модулей .py в каталоге: {len(py_modules)} — {py_modules}")

failures = []
for m in py_modules:
    try:
        mod = __import__(m)
        print(f"  ok   импорт {m}")
        if m == "main":
            checks = getattr(mod, "CHECKS", None)
            if checks is None:
                print("  FAIL: main.CHECKS не найден после импорта")
                failures.append((m, "CHECKS не найден"))
            else:
                print(f"  len(CHECKS)={len(checks)}")
    except Exception as e:  # noqa: BLE001 — фиксируем любой провал импорта
        print(f"  FAIL импорт {m}: {type(e).__name__}: {e}")
        failures.append((m, str(e)))

print()
print(f"модулей проверено: {len(py_modules)}, провалов импорта: {len(failures)}")
if failures:
    for m, err in failures:
        print(f"  провал: {m} — {err}")
    sys.exit(1)

UTC_END = datetime.now(timezone.utc).isoformat()
print(f"date -u (конец скрипта): {UTC_END}")
