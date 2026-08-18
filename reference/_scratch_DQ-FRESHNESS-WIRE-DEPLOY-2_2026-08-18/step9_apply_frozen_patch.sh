#!/usr/bin/env bash
set -euo pipefail

echo "=== UTC anchor (start) ==="
date -u
echo "=== gcloud auth list (start) ==="
gcloud auth list

SCRATCH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$SCRATCH_DIR/holika-prod"
HOLIKA_MAIN_PY="/Users/ilyasbazarov/Desktop/msklad_project/holika/worktrees/DQ-FRESHNESS-WIRE-DEPLOY-2/reference/code/cf-dq/main.py"

cd "$REPO_DIR"
git status --short
echo "--- current branch ---"
git branch --show-current

echo "--- apply: replace cf-dq/main.py with holika reference/code/cf-dq/main.py (identical content to failed attempt, CHECKS relocated — verified step8) ---"
cp "$HOLIKA_MAIN_PY" cf-dq/main.py

echo "--- git status after patch ---"
git status --short

echo "--- git diff --stat vs HEAD (prod-commit) ---"
git diff --stat

echo "=== UTC anchor (end) ==="
date -u
echo "=== gcloud auth list (end) ==="
gcloud auth list
