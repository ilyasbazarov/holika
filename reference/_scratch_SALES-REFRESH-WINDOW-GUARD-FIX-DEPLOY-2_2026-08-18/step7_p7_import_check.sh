#!/usr/bin/env bash
set -euo pipefail

echo "=== UTC anchor (start) ==="
date -u
echo "=== gcloud auth list (start) ==="
gcloud auth list

SCRATCH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$SCRATCH_DIR/holika-prod"
BRANCH=deploy/cf-facts-2026-08-18-guard-fix-f3-v2

cd "$REPO_DIR"
git checkout "$BRANCH"
echo "HEAD ветки деплоя: $(git rev-parse HEAD)"

PY=/opt/homebrew/bin/python3.14
echo "используемый интерпретатор: $PY"
"$PY" --version

echo "=== П7: импорт всех модулей cf-facts из каталога ВЕТКИ (не reference/code/) ==="
"$PY" "$SCRATCH_DIR/import_check.py" "$REPO_DIR/cf-facts"

echo "=== UTC anchor (end) ==="
date -u
echo "=== gcloud auth list (end) ==="
gcloud auth list
