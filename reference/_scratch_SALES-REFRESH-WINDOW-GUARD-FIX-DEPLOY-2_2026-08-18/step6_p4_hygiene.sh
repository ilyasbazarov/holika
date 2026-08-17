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

echo "=== П4a: git diff --stat против базы 543b6c1 (ожидание — ровно два файла) ==="
git diff --stat 543b6c1
FILE_COUNT=$(git diff --name-only 543b6c1 | wc -l | tr -d ' ')
echo "FILE_COUNT=$FILE_COUNT"
echo "файлы:"
git diff --name-only 543b6c1

echo "=== П4b: .gcloudignore в cf-facts/ ==="
cat cf-facts/.gcloudignore

echo "=== П4c: сплошной поиск секретов по диффу против базы 543b6c1, печать совпавших строк ==="
git diff 543b6c1 -- cf-facts/bq_ops.py cf-facts/main.py | grep -nE "token|secret|password|key|api[_-]?key" -i || echo "0 совпадений на слова token/secret/password/key/api_key"

echo "=== UTC anchor (end) ==="
date -u
echo "=== gcloud auth list (end) ==="
gcloud auth list
