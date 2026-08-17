#!/usr/bin/env bash
set -euo pipefail

echo "=== UTC anchor (start) ==="
date -u
echo "=== gcloud auth list (start) ==="
gcloud auth list

DOC_REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRATCH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$SCRATCH_DIR/holika-prod"
BRANCH=deploy/cf-facts-2026-08-18-guard-fix-f3-v2

echo "doc-repo root: $DOC_REPO_ROOT"
echo "code-repo (scratch clone): $REPO_DIR"

echo "=== confirm frozen snapshot commits (doc-repo) ==="
cd "$DOC_REPO_ROOT"
git log --oneline -1 -- reference/code/cf-facts/bq_ops.py
git log --oneline -1 -- reference/code/cf-facts/main.py

echo "=== copy exactly two files: bq_ops.py, main.py (no other files touched) ==="
cd "$REPO_DIR"
git checkout "$BRANCH"
cp "$DOC_REPO_ROOT/reference/code/cf-facts/bq_ops.py" cf-facts/bq_ops.py
cp "$DOC_REPO_ROOT/reference/code/cf-facts/main.py" cf-facts/main.py

echo "=== git status before commit ==="
git status --short

echo "=== git diff --stat against base 543b6c1 ==="
git diff --stat 543b6c1

echo "=== local commit (not pushed) ==="
git add cf-facts/bq_ops.py cf-facts/main.py
git commit -m "cf-facts: guard-fix ф3/ф4 (a5c6a36/56d40c1) поверх базы 543b6c1"
git log -1 --format="%H %s"

echo "=== confirm branch NOT pushed to origin ==="
git ls-remote origin "refs/heads/$BRANCH" || echo "подтверждено: ветка отсутствует на origin"

echo "=== UTC anchor (end) ==="
date -u
echo "=== gcloud auth list (end) ==="
gcloud auth list
