#!/usr/bin/env bash
# Провенанс ревью GUARD-FIX-PREP2-REVIEW (2026-08-18).
# Класс A: только чтение репо и локальный запуск Python по снапшоту. Облачных вызовов нет.
# UTC-якорь первой и последней командой (ADR-055 §3/§4).
set -u
cd "$(git rev-parse --show-toplevel)"
CF=reference/code/cf-facts

echo "=== UTC-якорь (начало) ==="; date -u
echo "=== база ==="; git rev-parse HEAD
echo "=== версии интерпретаторов (ADR-186 §5iii) ==="
python3 --version 2>&1
(python3.14 --version 2>&1) || echo "python3.14 отсутствует"

echo
echo "=== П1. Три уровня обвязки — печать совпавших строк с номерами (ADR-044) ==="
grep -n "_run_promote(\|_run_perimeter_promote(\|promote_to_core(\|promote_perimeter_to_core(\|_parse_run_started_at(" \
  "$CF"/*.py

echo
echo "=== П2. Машинный обход ВСЕХ вызовов: не осталось ли старой арности ==="
python3 - <<'PY'
import ast, glob
TARGETS = {'promote_to_core': 3, 'promote_perimeter_to_core': 3,
           '_run_promote': 2, '_run_perimeter_promote': 2}
defs, calls, bad = {}, [], []
for p in sorted(glob.glob('reference/code/cf-facts/*.py')):
    tree = ast.parse(open(p).read())
    for n in ast.walk(tree):
        if isinstance(n, ast.FunctionDef) and n.name in TARGETS:
            defs[n.name] = (p, n.lineno, len(n.args.args),
                            len(n.args.defaults), [a.arg for a in n.args.args])
        if isinstance(n, ast.Call) and isinstance(n.func, ast.Name) and n.func.id in TARGETS:
            calls.append((p, n.lineno, n.func.id, len(n.args), len(n.keywords)))
print('-- определения --')
for name, (p, ln, na, nd, args) in sorted(defs.items()):
    req = na - nd
    print(f'   {p}:{ln} def {name}({", ".join(args)}) — параметров {na}, обязательных {req}')
    if req != TARGETS[name]:
        bad.append(f'{name}: обязательных {req}, ожидалось {TARGETS[name]}')
print('-- вызовы --')
for p, ln, name, na, nk in sorted(calls):
    ok = (na + nk) == TARGETS[name]
    print(f'   {p}:{ln} {name}(...) — аргументов {na + nk} — {"ok" if ok else "СТАРАЯ АРНОСТЬ"}')
    if not ok:
        bad.append(f'{p}:{ln} {name} аргументов {na + nk}, ожидалось {TARGETS[name]}')
print('вызовов найдено:', len(calls), '· расхождений:', len(bad))
for b in bad:
    print('   РАСХОЖДЕНИЕ:', b)
PY

echo
echo "=== П2a. Дефекты ПОРЯДКА определений на уровне модуля — все файлы cf-facts (ADR-186 §5) ==="
python3 - <<'PY'
import ast, builtins, glob
def comp_bound(node):
    b = set()
    for x in ast.walk(node):
        if isinstance(x, (ast.ListComp, ast.SetComp, ast.DictComp, ast.GeneratorExp)):
            for g in x.generators:
                for y in ast.walk(g.target):
                    if isinstance(y, ast.Name): b.add(y.id)
        if isinstance(x, ast.Lambda):
            for a in x.args.args: b.add(a.arg)
    return b
files = sorted(glob.glob('reference/code/cf-facts/*.py'))
bad = 0
for p in files:
    tree = ast.parse(open(p).read()); defined, out = set(), []
    for n in tree.body:
        if isinstance(n, (ast.Import, ast.ImportFrom)):
            for a in n.names: defined.add((a.asname or a.name).split('.')[0])
        elif isinstance(n, (ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef)):
            defined.add(n.name)
        elif isinstance(n, (ast.Assign, ast.AnnAssign)):
            v = getattr(n, 'value', None)
            if v is not None:
                loc = comp_bound(v)
                used = {x.id for x in ast.walk(v)
                        if isinstance(x, ast.Name) and isinstance(x.ctx, ast.Load)}
                miss = sorted(u for u in used
                              if u not in defined and u not in loc and not hasattr(builtins, u))
                if miss: out.append((n.lineno, miss))
            tg = n.targets if isinstance(n, ast.Assign) else [n.target]
            for t in tg:
                for x in ast.walk(t):
                    if isinstance(x, ast.Name): defined.add(x.id)
    if out:
        bad += 1; print('ДЕФЕКТ ПОРЯДКА:', p, out)
print('проверено файлов:', len(files), '· с дефектом порядка:', bad)
PY

echo
echo "=== П3/П4. py_compile обоих патченных файлов ==="
python3 -m py_compile "$CF/main.py" "$CF/bq_ops.py" && echo "py_compile: ok (rc=0)"

echo
echo "=== П4a. ФАКТ-ПРОВЕРКА ИСПОЛНЕНИЕМ: реальный импорт патченных модулей (ADR-186 §5) ==="
PY_IMPORT=python3
command -v python3.14 >/dev/null 2>&1 && PY_IMPORT=python3.14
echo "интерпретатор импорта: $($PY_IMPORT --version 2>&1)"
$PY_IMPORT - <<'PY'
import sys, types, os, importlib

# Стабы внешних зависимостей. Отсутствие пакета на этой машине НЕ есть дефект патча
# (ADR-186 §5ii/§5iii), поэтому стаб намеренно снисходителен: любой атрибут существует
# и вызывается. Цель этой проверки одна — исполнить тело модуля сверху вниз и поймать
# ошибки ПОРЯДКА/ИМЁН, которые текстовое ревью не видит.
class _Lenient:
    def __init__(self, name='?'): self._name = name
    def __getattr__(self, item): return _Lenient(f'{self._name}.{item}')
    def __call__(self, *a, **k): return _Lenient(self._name + '()')
    def __iter__(self): return iter(())
    def __repr__(self): return f'<stub {self._name}>'

class _LenientModule(types.ModuleType):
    def __getattr__(self, item): return _Lenient(f'{self.__name__}.{item}')

for name in ('flask', 'requests', 'tenacity', 'functions_framework',
             'google', 'google.cloud', 'google.cloud.bigquery',
             'google.cloud.storage', 'google.cloud.secretmanager',
             'google.api_core', 'google.api_core.exceptions'):
    sys.modules[name] = _LenientModule(name)
sys.modules['google'].cloud = sys.modules['google.cloud']
for sub in ('bigquery', 'storage', 'secretmanager'):
    setattr(sys.modules['google.cloud'], sub, sys.modules['google.cloud.' + sub])

sys.path.insert(0, os.path.abspath('reference/code/cf-facts'))
failed = 0
for mod in ('config', 'helpers', 'bq_ops', 'main'):
    try:
        importlib.import_module(mod)
        print('  импорт ok:', mod)
    except Exception as e:
        failed += 1
        print('  импорт ПРОВАЛ:', mod, '->', type(e).__name__, e)
print('модулей с провалом импорта:', failed)
PY

echo
echo "=== П5. Три вида run_id + fail-closed на неразбираемом ==="
PY_IMPORT2=python3
command -v python3.14 >/dev/null 2>&1 && PY_IMPORT2=python3.14
$PY_IMPORT2 - <<'PY'
import sys, types, os, importlib
class _Lenient:
    def __init__(self, name='?'): self._name = name
    def __getattr__(self, item): return _Lenient(f'{self._name}.{item}')
    def __call__(self, *a, **k): return _Lenient(self._name + '()')
    def __iter__(self): return iter(())
class _LenientModule(types.ModuleType):
    def __getattr__(self, item): return _Lenient(f'{self.__name__}.{item}')
for name in ('flask', 'requests', 'tenacity', 'functions_framework',
             'google', 'google.cloud', 'google.cloud.bigquery',
             'google.cloud.storage', 'google.cloud.secretmanager',
             'google.api_core', 'google.api_core.exceptions'):
    sys.modules[name] = _LenientModule(name)
sys.modules['google'].cloud = sys.modules['google.cloud']
for sub in ('bigquery', 'storage', 'secretmanager'):
    setattr(sys.modules['google.cloud'], sub, sys.modules['google.cloud.' + sub])
sys.path.insert(0, os.path.abspath('reference/code/cf-facts'))
main = importlib.import_module('main')
f = main._parse_run_started_at
cases = [
    ('float эпохи (sys.now())',        1786842001.2609222, True),
    ('строка-число того же вида',      "1786842001.2609222", True),
    ('строка %Y%m%dT%H%M%S (run_ts)',  "20260816T011821",   True),
    ('неразбираемая строка',           "abc",               False),
    ('None (вызов без run_id)',        None,                False),
]
for label, val, should_pass in cases:
    try:
        r = f(val)
        verdict = 'разобрано -> ' + r.isoformat()
        ok = should_pass
    except ValueError as e:
        verdict = 'ОТКАЗ (fail-closed): ' + str(e)[:70] + '…'
        ok = not should_pass
    print(f'  [{"ok" if ok else "НЕ ТО"}] {label}: {verdict}')
PY

echo
echo "=== П5a. Оба контроля на числах инцидента 2026-08-16 — ВОСПРОИЗВЕДЕНИЕ стенда PREP2 ==="
echo "(запускаю чужой стенд по ТЕКУЩЕМУ снапшоту: приёмка §7 п.5 требует прогона через main(),"
echo " а не через promote_to_core напрямую; переиспользование чужого стенда законно, свой"
echo " не переписываю — иначе проверял бы свою реализацию, а не патч)"
$PY_IMPORT2 reference/_scratch_SALES-REFRESH-WINDOW-GUARD-FIX-PREP2_2026-08-18/verify_promote_chain.py 2>&1 | tail -30

echo
echo "=== П6. Дифф: нижний край, GUARD_TOLERANCE_DAYS и тела MERGE не изменены ==="
echo "-- файлы, затронутые коммитом PREP2 (56d40c1) --"
git show --name-only --format="" 56d40c1 -- reference/code/
echo "-- есть ли GUARD_TOLERANCE_DAYS в диффе PREP2 --"
git show 56d40c1 -- reference/code/ | grep -nE "^[+-].*GUARD_TOLERANCE_DAYS" || echo "  совпадений 0 — не тронут"
echo "-- есть ли в диффе PREP2 строки тел MERGE --"
git show 56d40c1 -- reference/code/ | grep -nE "^[+-].*(WHEN MATCHED|WHEN NOT MATCHED|MERGE .INTO|_build_merge_sql|_build_perimeter_merge_sql)" || echo "  совпадений 0 — не тронуты"
echo "-- где живёт GUARD_TOLERANCE_DAYS сейчас --"
grep -rn "GUARD_TOLERANCE_DAYS" reference/code/cf-facts/ || echo "  не найден"

echo
echo "=== П7. Предохранитель: верхний край и нижний край в bq_ops.py ==="
grep -n "_assert_staging_covers_merge_window" -A 40 reference/code/cf-facts/bq_ops.py | head -60

echo
echo "=== UTC-якорь (конец) ==="; date -u
