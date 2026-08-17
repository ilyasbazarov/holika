#!/usr/bin/env bash
set -euo pipefail

echo "=== UTC anchor (start) ==="
date -u
echo "=== gcloud auth list (start) ==="
gcloud auth list

SCRATCH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$SCRATCH_DIR/holika-prod"
cd "$REPO_DIR"

BASE_COMMIT=543b6c1
BRANCH=deploy/cf-facts-2026-08-18-guard-fix-f3-v2
git checkout "$BRANCH"

echo "=== П6: git merge-base --is-ancestor $BASE_COMMIT <HEAD ветки деплоя> ==="
echo "HEAD ветки деплоя: $(git rev-parse HEAD)"
if git merge-base --is-ancestor "$BASE_COMMIT" HEAD; then
  echo "П6 РЕЗУЛЬТАТ: ИСТИНА — $BASE_COMMIT является предком HEAD ветки деплоя"
else
  RC=$?
  echo "П6 РЕЗУЛЬТАТ: ЛОЖЬ (rc=$RC) — $BASE_COMMIT НЕ предок HEAD ветки деплоя — СТОП"
fi

echo "=== UTC anchor (end) ==="
date -u
echo "=== gcloud auth list (end) ==="
gcloud auth list
