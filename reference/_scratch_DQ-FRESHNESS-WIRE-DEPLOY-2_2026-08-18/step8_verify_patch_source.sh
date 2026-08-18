#!/usr/bin/env bash
set -euo pipefail

echo "=== UTC anchor (start) ==="
date -u
echo "=== gcloud auth list (start) ==="
gcloud auth list

SCRATCH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$SCRATCH_DIR/holika-prod"
HOLIKA_MAIN_PY="/Users/ilyasbazarov/Desktop/msklad_project/holika/worktrees/DQ-FRESHNESS-WIRE-DEPLOY-2/reference/code/cf-dq/main.py"

echo "=== контроль: сколько пар в CHECKS у прод-коммита (базы) ==="
cd "$REPO_DIR"
git show c9b967ffcae01ceeae3b6fd0e6e2cba0549ed738:cf-dq/main.py | awk '/^CHECKS = \[/,/^\]/' | grep -c '(' || true

echo "=== контроль: сколько пар в CHECKS у неудачной попытки (origin/deploy/cf-dq-2026-08-18-freshness-wire) ==="
git show origin/deploy/cf-dq-2026-08-18-freshness-wire:cf-dq/main.py | awk '/^CHECKS = \[/,/^\]/' | grep -c '(' || true

echo "=== диф: неудачная попытка (origin/deploy/cf-dq-2026-08-18-freshness-wire) vs holika reference/code/cf-dq/main.py (уже исправленный) ==="
diff <(git show origin/deploy/cf-dq-2026-08-18-freshness-wire:cf-dq/main.py) "$HOLIKA_MAIN_PY" || true

echo "=== контроль: сколько пар в CHECKS у holika reference/code/cf-dq/main.py (целевое содержание патча) ==="
awk '/^CHECKS = \[/,/^\]/' "$HOLIKA_MAIN_PY" | grep -c '(' || true

echo "=== контроль: try/except во всех 12 check_freshness_* в целевом файле ==="
grep -c "^def check_freshness_" "$HOLIKA_MAIN_PY"
grep -A3 "^def check_freshness_" "$HOLIKA_MAIN_PY" | grep -c "try:"

echo "=== UTC anchor (end) ==="
date -u
echo "=== gcloud auth list (end) ==="
gcloud auth list
