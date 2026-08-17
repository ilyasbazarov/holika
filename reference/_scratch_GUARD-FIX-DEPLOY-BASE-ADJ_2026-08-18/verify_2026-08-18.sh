#!/usr/bin/env bash
# Провенанс адъюдикации GUARD-FIX-DEPLOY-BASE-ADJ (2026-08-18).
# Класс A: чтение репо и файлов провенанса чужой сессии. Облачных вызовов нет.
set -u
cd "$(git rev-parse --show-toplevel)"
# Дерево чужой сессии лежит РЯДОМ с этим, а не внутри него: её ветка не слита, поэтому
# относительный путь от корня СВОЕГО дерева не резолвится. Берём путь из git worktree list.
MAIN=$(git worktree list --porcelain | awk '/^worktree /{print $2; exit}')
PEER="$MAIN/worktrees/SALES-REFRESH-WINDOW-GUARD-FIX-DEPLOY/reference/_scratch_SALES-REFRESH-WINDOW-GUARD-FIX-DEPLOY_2026-08-18"
CLONE="$PEER/holika-prod"

echo "=== UTC-якорь (начало) ==="; date -u
echo "=== база ==="; git rev-parse HEAD

echo
echo "=== 1. Цикл, делающий вариант 2 недостижимым — цитаты из репо со строками ==="
echo "-- слияние в master запрещено до ступени 3 --"
grep -n "ЗАПРЕЩЕНО до ступени 3" 07_STATE.md | cut -c1-200
echo "-- ступень 3 закрывается ПОСЛЕ выкладки guard-fix --"
grep -no "ступень 3 закрывается первым недельным прогоном[^|]*" 07_STATE.md | cut -c1-260

echo
echo "=== 2. Состояние клона код-репо в провенансе чужой сессии ==="
echo "-- собственного .git у клона нет, поэтому git-команды в нём резолвятся в doc-репо --"
test -d "$CLONE/.git" && echo "   .git ЕСТЬ" || echo "   .git НЕТ — читаем файлы, а не git-историю"
echo "-- контроль: рабочее дерево клона оставлено на master (step4 делает git checkout master) --"
grep -n "git checkout master" "$PEER/step4_precondition_p2_p3.sh"
echo "-- подтверждение той же трактовки по содержимому: ветка удаления в bq_ops.py --"
printf '   клон (master): '; grep -c "WHEN NOT MATCHED BY SOURCE" "$CLONE/cf-facts/bq_ops.py"
printf '   снапшот doc-репо: '; grep -c "WHEN NOT MATCHED BY SOURCE" reference/code/cf-facts/bq_ops.py

echo
echo "=== 3. Что произошло бы при деплое ветки, заведённой от master ==="
python3 - "$CLONE/cf-facts" <<'PY'
import ast, sys, os
master_cf = sys.argv[1]

def imported_from_config(path):
    for n in ast.parse(open(path).read()).body:
        if isinstance(n, ast.ImportFrom) and n.module == 'config':
            return [a.name for a in n.names]
    return []

def defined_names(path):
    out = set()
    for n in ast.parse(open(path).read()).body:
        if isinstance(n, ast.Assign):
            for t in n.targets:
                for x in ast.walk(t):
                    if isinstance(x, ast.Name):
                        out.add(x.id)
    return out

want = imported_from_config('reference/code/cf-facts/bq_ops.py')     # объект деплоя
have_master = defined_names(os.path.join(master_cf, 'config.py'))    # config.py остаётся от master
have_snap = defined_names('reference/code/cf-facts/config.py')       # контроль

miss_master = [w for w in want if w not in have_master]
miss_snap = [w for w in want if w not in have_snap]

print('bq_ops.py (объект деплоя) импортирует из config на уровне модуля:', len(want), 'имён')
print('config.py ветки master определяет:', len(have_master), 'имён')
print('ОТСУТСТВУЮТ в master (отрицательный контроль):', miss_master or 'нет')
print('ОТСУТСТВУЮТ в снапшоте doc-репо (положительный контроль):', miss_snap or 'нет')
print()
print('Вывод: ветка "master + два файла снапшота" даёт ImportError на уровне импорта модуля,')
print('то есть контейнер не стартует. Это тот же класс отказа, что уронил cf-dq 2026-08-18.')
PY

echo
echo "=== 4. Статус слияний веток cf-facts по MANIFEST (какие в master, какие нет) ==="
grep -n "Слияние в \`master\`\|НЕ слита\|только ПОСЛЕ ступени 3\|Слияние ветки" reference/code/cf-facts/MANIFEST.md | tail -8 | cut -c1-190

echo
echo "=== UTC-якорь (конец) ==="; date -u
