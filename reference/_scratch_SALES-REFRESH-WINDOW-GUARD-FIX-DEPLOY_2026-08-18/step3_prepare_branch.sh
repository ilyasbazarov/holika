#!/usr/bin/env bash
set -euo pipefail

# Готовит ветку деплоя ЛОКАЛЬНО в клоне код-репо (без push): копирует ровно два файла из
# проверенного снапшота doc-репо reference/code/cf-facts/{bq_ops.py,main.py} (== HEAD 56d40c1)
# поверх master код-репо, коммитит, проверяет ровно 2 файла в diff --stat master (ADR-189 §3),
# сверяет .gcloudignore (ADR-040) и делает сплошной поиск секретов по диффу (ADR-044).

SCRATCH="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$SCRATCH/holika-prod"
DOCREPO_SNAPSHOT="/Users/ilyasbazarov/Desktop/msklad_project/holika/worktrees/SALES-REFRESH-WINDOW-GUARD-FIX-DEPLOY/reference/code/cf-facts"
BRANCH="deploy/cf-facts-2026-08-18-guard-fix-f3"

echo "=== UTC anchor (start) ==="
date -u
echo "=== identity (start) ==="
gcloud auth list

cd "$REPO_DIR"
git checkout master
git pull --ff-only origin master
echo "master HEAD (fresh): $(git rev-parse master)"

echo "=== creating branch $BRANCH from master ==="
git checkout -b "$BRANCH" master

echo "=== copying exactly two files from doc-repo snapshot (== commit 56d40c1) ==="
cp "$DOCREPO_SNAPSHOT/bq_ops.py" cf-facts/bq_ops.py
cp "$DOCREPO_SNAPSHOT/main.py" cf-facts/main.py

echo "=== git status before commit ==="
git status --porcelain

git add cf-facts/bq_ops.py cf-facts/main.py
git commit -m "deploy: cf-facts guard-fix f3 (bq_ops.py верхний край + main.py run_started_at)

Перенесено из doc-репо holika, коммиты a5c6a36 (bq_ops.py, форма ф3) и 56d40c1
(main.py, обвязка run_started_at). Мандат ADR-189, guard_fix_deploy_mandate_2026-08-18.md."

echo "=== git diff --stat master (ОБЯЗАНО показать ровно 2 файла — ADR-189 §3) ==="
git diff --stat master

NFILES=$(git diff --name-only master | wc -l | tr -d ' ')
echo "NFILES=$NFILES"
if [ "$NFILES" -ne 2 ]; then
  echo "СТОП: git diff --stat master показывает $NFILES файлов, ожидалось ровно 2."
  exit 1
fi

echo "=== .gcloudignore (cf-facts/) — сверка с ADR-040 ==="
cat cf-facts/.gcloudignore

echo "=== сплошной поиск секретов по диффу (ADR-044, пустая выдача не факт) ==="
git diff master -- cf-facts/bq_ops.py cf-facts/main.py | grep -inE "secret|token|password|api[_-]?key|private[_-]?key|BEGIN (RSA|PRIVATE)" || echo "0 совпадений (grep -c проверка ниже)"
git diff master -- cf-facts/bq_ops.py cf-facts/main.py | grep -icE "secret|token|password|api[_-]?key|private[_-]?key|BEGIN (RSA|PRIVATE)"

echo "=== new branch HEAD ==="
git rev-parse "$BRANCH"

echo "=== UTC anchor (end) ==="
date -u
echo "=== identity (end) ==="
gcloud auth list
