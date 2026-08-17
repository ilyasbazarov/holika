"""
П7 (guard_fix_deploy_mandate_2026-08-18_rev2.md §2) — факт-проверка исполнением
(05_CONVENTIONS §Процедура деплоя п.9) на СОДЕРЖИМОМ ВЕТКИ ДЕПЛОЯ, не на снапшоте
reference/code/. Импортирует все модули cf-facts из каталога, переданного первым
аргументом (ожидается путь на ветку деплоя код-репо).

Внешние зависимости (google.cloud.bigquery/storage/secretmanager, flask, requests,
tenacity) подставляются снисходительными стабами: любой атрибут — вызываемый
объект (`__getattr__`), любой вызов возвращает ещё один такой же объект. Это форма,
которую guard_fix_prep2_review_2026-08-18.md §3 называет рабочей — жёсткие стабы
(явный список имён) дали ложный провал на tenacity.before_sleep_log/bigquery.SchemaField.
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
    print("usage: import_check.py <cf-facts-dir>")
    sys.exit(2)

CF_FACTS_DIR = os.path.abspath(sys.argv[1])
print(f"каталог проверки (ветка деплоя): {CF_FACTS_DIR}")
sys.path.insert(0, CF_FACTS_DIR)


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
    "google", "google.cloud", "google.cloud.bigquery", "google.cloud.storage",
    "google.cloud.secretmanager", "flask", "requests", "tenacity",
]:
    sys.modules[modname] = _stub_module(modname)

# google.cloud.* должны быть атрибутами google.cloud, не только записями sys.modules
sys.modules["google"].cloud = sys.modules["google.cloud"]
sys.modules["google.cloud"].bigquery = sys.modules["google.cloud.bigquery"]
sys.modules["google.cloud"].storage = sys.modules["google.cloud.storage"]
sys.modules["google.cloud"].secretmanager = sys.modules["google.cloud.secretmanager"]

py_modules = sorted(
    f[:-3] for f in os.listdir(CF_FACTS_DIR)
    if f.endswith(".py")
)
print(f"модулей .py в каталоге: {len(py_modules)} — {py_modules}")

failures = []
for m in py_modules:
    try:
        __import__(m)
        print(f"  ok   импорт {m}")
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
