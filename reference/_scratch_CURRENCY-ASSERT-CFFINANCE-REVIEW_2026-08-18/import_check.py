"""Факт-проверка ИСПОЛНЕНИЕМ (05_CONVENTIONS §Процедура деплоя п.9, ADR-186 §6).
Стабы СНИСХОДИТЕЛЬНЫЕ (__getattr__ отдаёт вызываемый объект) — иначе получаем
ложный вердикт «патч не импортируется» на атрибуте чужой библиотеки (07_STATE §Подробности)."""
import sys, types, importlib.util, pathlib

class Lenient(types.ModuleType):
    def __getattr__(self, name):
        m = Lenient(f"{self.__name__}.{name}")
        sys.modules[f"{self.__name__}.{name}"] = m
        return m
    def __call__(self, *a, **k):
        return Lenient(self.__name__ + "()")

for name in ["requests", "google", "google.cloud", "google.cloud.bigquery",
             "google.cloud.bigquery_datatransfer", "google.protobuf",
             "google.protobuf.timestamp_pb2", "tenacity"]:
    sys.modules.setdefault(name, Lenient(name))

src = pathlib.Path(sys.argv[1]).resolve()
sys.path.insert(0, str(src.parent))          # чтобы `import invoices` разрешился из того же каталога
failed = []
for mod in ["invoices", "main"]:
    try:
        spec = importlib.util.spec_from_file_location(mod, src.parent / f"{mod}.py")
        m = importlib.util.module_from_spec(spec)
        sys.modules[mod] = m
        spec.loader.exec_module(m)
        print(f"OK   импорт {mod}.py")
    except Exception as e:
        failed.append((mod, e))
        print(f"FAIL импорт {mod}.py — {type(e).__name__}: {e}")

if not failed:
    import main as m
    for fn in ["parse_href", "_fetch_currency_map", "run_etl", "trigger_marts", "main"]:
        print(f"  имя {fn}: {'есть' if hasattr(m, fn) else 'НЕТ'}")
    print("  parse_href(None) =", m.parse_href(None))
    print("  parse_href({'meta':{'href':'https://x/y/uuid-1'}}) =",
          m.parse_href({"meta": {"href": "https://x/y/uuid-1"}}))
    print("  parse_href({'meta': None}) =", end=" ")
    try:
        print(m.parse_href({"meta": None}))
    except Exception as e:
        print(f"ИСКЛЮЧЕНИЕ {type(e).__name__}: {e}")

print("=== VERDICT ===")
print("ALL IMPORTS OK" if not failed else f"IMPORT FAILURES: {len(failed)}")
sys.exit(0 if not failed else 1)
