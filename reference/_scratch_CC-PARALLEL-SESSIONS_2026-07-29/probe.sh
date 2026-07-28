#!/usr/bin/env bash
ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT" || exit 1

echo "=== ANCHOR START ==="; date -u
echo "ROOT: $ROOT"

echo; echo "=== G1: версия инструмента и режим деревьев ==="
claude --version 2>&1 || echo "claude: не найден в PATH этого терминала"
echo "--- git worktree list ---"
git worktree list 2>&1
echo "--- .claude/worktrees в gitignore? ---"
git check-ignore -v .claude/worktrees/probe 2>&1 || echo "НЕ игнорируется"

echo; echo "=== G1b: расхождение локального main и origin/main (ловушка baseRef) ==="
git rev-parse HEAD 2>&1
git rev-parse --abbrev-ref HEAD 2>&1
echo "локальных коммитов впереди origin/main:"
git rev-list --count origin/main..HEAD 2>&1 || echo "origin/main не найден локально"
echo "--- git status --short ---"
git status --short 2>&1

echo; echo "=== G2: достижимость хука из связанного дерева ==="
WT="$ROOT/../_holika_probe_hook"
git worktree add -b probe/hook-check "$WT" HEAD 2>&1
if [ -d "$WT" ]; then
  (
    cd "$WT" || exit 1
    echo "--- git-dir и общий git-dir ---"
    git rev-parse --git-dir 2>&1
    git rev-parse --git-common-dir 2>&1
    echo "--- что лежит в hooks/pre-commit ---"
    ls -l "$(git rev-parse --git-common-dir)/hooks/pre-commit" 2>&1
    readlink "$(git rev-parse --git-common-dir)/hooks/pre-commit" 2>&1
    echo "--- заведомо провальный коммит: правка 07_STATE без updated_at ---"
    printf '\nprobe line for hook verification\n' >> 07_STATE.md
    git add 07_STATE.md 2>&1
    git commit -m "probe: hook reachability from linked worktree" 2>&1
    echo "RC КОММИТА: $?"
  )
  echo "--- уборка пробного дерева ---"
  git worktree remove --force "$WT" 2>&1
  git branch -D probe/hook-check 2>&1
else
  echo "пробное дерево не создалось, см. вывод выше"
fi
echo "--- состояние основного дерева после уборки ---"
git status --short 2>&1

echo; echo "=== G3: git-команды из транскриптов сессий ==="
python3 - <<'PY'
import json, os, glob
base = os.path.expanduser('~/.claude/projects')
print('BASE:', base, 'exists:', os.path.isdir(base))
files = glob.glob(os.path.join(base, '*', '*.jsonl'))
print('файлов транскриптов:', len(files))
hits = 0
for f in files:
    try:
        fh = open(f, 'r', encoding='utf-8', errors='replace')
    except Exception as e:
        print('OPEN FAIL', f, e); continue
    with fh:
        for line in fh:
            if 'git commit' not in line and 'git add' not in line:
                continue
            try:
                o = json.loads(line)
            except Exception:
                continue
            ts = o.get('timestamp', '') or ''
            if not (ts.startswith('2026-07-28') or ts.startswith('2026-07-29')):
                continue
            msg = o.get('message') or {}
            content = msg.get('content')
            if not isinstance(content, list):
                continue
            for b in content:
                if not isinstance(b, dict) or b.get('type') != 'tool_use':
                    continue
                cmd = (b.get('input') or {}).get('command')
                if not isinstance(cmd, str):
                    continue
                if 'git commit' not in cmd and 'git add' not in cmd:
                    continue
                hits += 1
                print('---')
                print('TS   :', ts)
                print('SESS :', os.path.basename(os.path.dirname(f)) + '/' + os.path.basename(f))
                print('CMD  :', cmd[:400].replace('\n', ' | '))
print('ВСЕГО СОВПАДЕНИЙ:', hits)
PY

echo; echo "=== ANCHOR END ==="; date -u
