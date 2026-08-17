#!/usr/bin/env bash
set -euo pipefail

# Read-only разведка код-репо holika-prod: свежий клон, проверка master, наличие
# коммитов a5c6a36 (bq_ops.py, форма ф3) / 56d40c1 (main.py, run_started_at), наличие
# ветки деплоя. Не создаёт и не пушит ничего.

SCRATCH="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$SCRATCH/holika-prod"

echo "=== UTC anchor (start) ==="
date -u
echo "=== identity (start) ==="
gcloud auth list

echo "=== clone code-repo master (read-only) ==="
rm -rf "$REPO_DIR"
git clone https://github.com/ilyasbazarov/holika-prod.git "$REPO_DIR"
cd "$REPO_DIR"
git checkout master
echo "master HEAD: $(git rev-parse master)"

echo "=== searching for target commits a5c6a36 / 56d40c1 (all branches) ==="
git fetch origin '+refs/heads/*:refs/remotes/origin/*'
git log --all --oneline | grep -E "^a5c6a36|^56d40c1" || echo "NOT FOUND in --oneline (short hash may differ in length)"
git cat-file -e a5c6a36 2>/dev/null && echo "a5c6a36 exists as object" || echo "a5c6a36 MISSING as object"
git cat-file -e 56d40c1 2>/dev/null && echo "56d40c1 exists as object" || echo "56d40c1 MISSING as object"

echo "=== branches containing a5c6a36 ==="
git branch -a --contains a5c6a36 2>/dev/null || echo "none / not an ancestor of any branch tip"
echo "=== branches containing 56d40c1 ==="
git branch -a --contains 56d40c1 2>/dev/null || echo "none / not an ancestor of any branch tip"

echo "=== does deploy/cf-facts-2026-08-18-guard-fix-f3 already exist (local+remote)? ==="
git branch -a | grep -F "cf-facts-2026-08-18-guard-fix-f3" || echo "does not exist yet"

echo "=== master cf-facts/ file list ==="
ls -la cf-facts/

echo "=== master .gcloudignore (if present) ==="
cat .gcloudignore 2>/dev/null || echo "no top-level .gcloudignore"
cat cf-facts/.gcloudignore 2>/dev/null || echo "no cf-facts/.gcloudignore"

echo "=== UTC anchor (end) ==="
date -u
echo "=== identity (end) ==="
gcloud auth list
