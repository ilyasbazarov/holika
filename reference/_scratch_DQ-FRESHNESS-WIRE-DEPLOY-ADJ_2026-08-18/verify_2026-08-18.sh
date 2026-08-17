#!/usr/bin/env bash
# Провенанс адъюдикации DQ-FRESHNESS-WIRE-DEPLOY-ADJ (2026-08-18).
# Класс A: только чтение репо, облачных вызовов нет. UTC-якорь первой и последней командой
# (ADR-055 §3/§4); подтверждение личности вызывающего не требуется — к облаку не обращаемся.
set -u
cd "$(git rev-parse --show-toplevel)"

echo "=== UTC-якорь (начало) ==="; date -u
echo "=== база ==="; git rev-parse HEAD

echo
echo "=== 1. Дефект порядка определений в ревьюнутом снапшоте cf-dq ==="
grep -n '^CHECKS = \[' reference/code/cf-dq/main.py
grep -n '^def check_freshness_[a-z]*_technical\|^def check_freshness_[a-z]*_business' reference/code/cf-dq/main.py

echo
echo "=== 2. Статическое разрешение имён на уровне модуля — все снапшоты reference/code ==="
python3 - <<'PY'
import ast, builtins, glob

def comprehension_bound(node):
    """Имена, связанные внутри comprehension/lambda — собственная область видимости."""
    b = set()
    for x in ast.walk(node):
        if isinstance(x, (ast.ListComp, ast.SetComp, ast.DictComp, ast.GeneratorExp)):
            for g in x.generators:
                for y in ast.walk(g.target):
                    if isinstance(y, ast.Name):
                        b.add(y.id)
        if isinstance(x, ast.Lambda):
            for a in x.args.args:
                b.add(a.arg)
    return b

files = sorted(glob.glob('reference/code/**/*.py', recursive=True))
bad = []
for p in files:
    tree = ast.parse(open(p).read())
    defined, out = set(), []
    for n in tree.body:
        if isinstance(n, (ast.Import, ast.ImportFrom)):
            for a in n.names:
                defined.add((a.asname or a.name).split('.')[0])
        elif isinstance(n, (ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef)):
            defined.add(n.name)
        elif isinstance(n, (ast.Assign, ast.AnnAssign)):
            v = getattr(n, 'value', None)
            if v is not None:
                local = comprehension_bound(v)
                used = {x.id for x in ast.walk(v)
                        if isinstance(x, ast.Name) and isinstance(x.ctx, ast.Load)}
                miss = sorted(u for u in used
                              if u not in defined and u not in local and not hasattr(builtins, u))
                if miss:
                    out.append((n.lineno, miss))
            targets = n.targets if isinstance(n, ast.Assign) else [n.target]
            for t in targets:
                for x in ast.walk(t):
                    if isinstance(x, ast.Name):
                        defined.add(x.id)
    if out:
        bad.append(p)
        print('ДЕФЕКТ ПОРЯДКА:', p)
        for ln, miss in out:
            print('   строка', ln, '— неопределённых имён:', len(miss))
            for m in miss:
                print('      ', m)
print('проверено файлов:', len(files), '· файлов с дефектом порядка:', len(bad))
PY

echo
echo "=== 3. Когда дефект родился — трассировка по истории файла ==="
git log --oneline -- reference/code/cf-dq/main.py | head -10
for sha in eaa53c1 9d766dd 36414c1 348f4ff c9905a3 e1cffe9; do
  printf '%s: ' "$sha"
  git show "${sha}":"reference/code/cf-dq/main.py" 2>/dev/null | python3 -c "
import ast, sys, builtins
src = sys.stdin.read()
if not src:
    print('ФАЙЛ ПУСТ — трассировка недостоверна'); raise SystemExit
tree = ast.parse(src); defined = set(); out = []
for n in tree.body:
    if isinstance(n, (ast.Import, ast.ImportFrom)):
        for a in n.names: defined.add((a.asname or a.name).split('.')[0])
    elif isinstance(n, (ast.FunctionDef, ast.ClassDef)): defined.add(n.name)
    elif isinstance(n, ast.Assign):
        used = {x.id for x in ast.walk(n.value) if isinstance(x, ast.Name) and isinstance(x.ctx, ast.Load)}
        miss = sorted(u for u in used if u not in defined and not hasattr(builtins, u))
        if miss: out.append((n.lineno, len(miss)))
        for t in n.targets:
            for x in ast.walk(t):
                if isinstance(x, ast.Name): defined.add(x.id)
print('ДЕФЕКТ' if out else 'чисто', out)
"
done

echo
echo "=== 4. Приземление коммитов доски (git merge-base --is-ancestor) ==="
for sha in c9905a3 e1cffe9 330e42b cc37bff 61e48c1 56d40c1; do
  if git merge-base --is-ancestor "$sha" main 2>/dev/null; then
    echo "  $sha — в main"
  else
    echo "  $sha — НЕ в main"
  fi
done

echo
echo "=== UTC-якорь (конец) ==="; date -u
