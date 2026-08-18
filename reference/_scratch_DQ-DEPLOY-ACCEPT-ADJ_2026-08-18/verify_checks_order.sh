#!/bin/bash
# Ревью архитектора: независимая факт-проверка патча DQ-FRESHNESS-WIRE-CHECKS-ORDER
# Класс A, read-only. Облачных вызовов нет.
set -u
cd /Users/ilyasbazarov/Desktop/msklad_project/holika || exit 1

echo "=== UTC-якорь (начало) ==="; date -u
echo "=== HEAD ==="; git rev-parse HEAD

F=reference/code/cf-dq/main.py

echo
echo "=== 1. Позиция блока CHECKS и точки входа (номера строк, ADR-044) ==="
grep -n "^CHECKS = \[\|^\]\|^def main(request)\|^@functions_framework.http\|^def check_freshness_invoices_business" "$F"

echo
echo "=== 2. Состав файла cf-dq/ ==="
ls -1 reference/code/cf-dq/
echo "--- .gcloudignore, если есть ---"
if [ -f reference/code/cf-dq/.gcloudignore ]; then cat reference/code/cf-dq/.gcloudignore; else echo "ФАЙЛА .gcloudignore НЕТ"; fi
echo "--- patch_dq.py в индексе git? ---"
git ls-files reference/code/cf-dq/ | sed 's/^/  /'

echo
echo "=== 3. Независимая проверка форвард-ссылок на уровне модуля (AST) ==="
python3 - "$F" <<'PY'
import ast, sys, builtins
p = sys.argv[1]
src = open(p, encoding="utf-8").read()
tree = ast.parse(src, p)
defined = set(dir(builtins))
problems = []
for node in tree.body:
    # имена, читаемые ЭТИМ верхнеуровневым узлом (тела функций/классов не разворачиваем)
    if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef)):
        scan = node.decorator_list + [a for a in [node.args] if not isinstance(node, ast.ClassDef)]
        for s in scan:
            for n in ast.walk(s):
                if isinstance(n, ast.Name) and isinstance(n.ctx, ast.Load) and n.id not in defined:
                    problems.append((n.lineno, n.id, "декоратор/сигнатура " + node.name))
        defined.add(node.name)
        continue
    for n in ast.walk(node):
        if isinstance(n, ast.Name) and isinstance(n.ctx, ast.Load) and n.id not in defined:
            problems.append((n.lineno, n.id, type(node).__name__))
    for n in ast.walk(node):
        if isinstance(n, ast.Name) and isinstance(n.ctx, ast.Store):
            defined.add(n.id)
        if isinstance(n, ast.alias):
            defined.add((n.asname or n.name).split(".")[0])
print("проблемных форвард-ссылок на уровне модуля:", len(problems))
for lineno, name, where in problems:
    print(f"  строка {lineno}: {name}  ({where})")
PY

echo
echo "=== 4. Состав CHECKS: имена пар и их количество (текстом, без импорта) ==="
awk '/^CHECKS = \[/,/^\]/' "$F" | grep -c '("'
echo "--- имена ---"
awk '/^CHECKS = \[/,/^\]/' "$F" | grep -o '("[a-z_]*"' | tr -d '("'

echo
echo "=== 5. Все ли двенадцать проверок свежести несут try/except (ADR-184) ==="
python3 - "$F" <<'PY'
import ast, sys
p = sys.argv[1]
tree = ast.parse(open(p, encoding="utf-8").read(), p)
bad = []
n = 0
for node in tree.body:
    if isinstance(node, ast.FunctionDef) and node.name.startswith("check_freshness_") and node.name != "check_freshness":
        n += 1
        has_try = any(isinstance(x, ast.Try) for x in ast.walk(node))
        # возвращает ли хоть где-то False на верхнем уровне return
        rets = [x for x in ast.walk(node) if isinstance(x, ast.Return)]
        false_rets = []
        for r in rets:
            v = r.value
            if isinstance(v, ast.Tuple) and v.elts:
                e = v.elts[0]
                if isinstance(e, ast.Constant) and e.value is False:
                    false_rets.append(r.lineno)
        if not has_try:
            bad.append((node.name, "нет try/except"))
        if node.name.endswith("_technical") and false_rets:
            bad.append((node.name, f"технический возвращает False на строках {false_rets}"))
print(f"функций check_freshness_*: {n}")
print(f"нарушений: {len(bad)}")
for name, why in bad:
    print(f"  {name}: {why}")
PY

echo
echo "=== 6. Дифф main.py между состоянием ДО правки и текущим ==="
git diff --stat 5b2d8df 67b65e5 -- "$F"
echo "--- сводка по типам строк (без содержимого) ---"
git diff 5b2d8df 67b65e5 -- "$F" | grep -c '^+[^+]'
git diff 5b2d8df 67b65e5 -- "$F" | grep -c '^-[^-]'
echo "--- есть ли изменения ВНЕ блока CHECKS: строки диффа, не начинающиеся с пары кавычек/скобки блока ---"
git diff 5b2d8df 67b65e5 -- "$F" | grep '^[+-][^+-]' | grep -v '^\([+-]\)\s*(\"' | grep -v '^\([+-]\)CHECKS = \[' | grep -v '^\([+-]\)\]$' | cat -A | head -20

echo
echo "=== 7. Все ли файлы, кроме main.py, не тронуты этой правкой ==="
git diff --stat 5b2d8df 67b65e5 -- reference/code/cf-dq/

echo
echo "=== UTC-якорь (конец) ==="; date -u
