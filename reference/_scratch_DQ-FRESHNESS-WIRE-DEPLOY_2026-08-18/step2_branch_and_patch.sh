#!/usr/bin/env bash
set -euo pipefail

echo "=== date -u (start) ==="
date -u
echo "=== gcloud auth list (start) ==="
gcloud auth list

SCRATCH="$(cd "$(dirname "$0")" && pwd)"
HOLIKA_ROOT="/Users/ilyasbazarov/Desktop/msklad_project/holika/worktrees/DQ-FRESHNESS-WIRE-DEPLOY"
REPO="$SCRATCH/code_repo"

rm -rf "$REPO"
git clone --quiet --branch master https://github.com/ilyasbazarov/holika-prod.git "$REPO"
cd "$REPO"
git checkout -q -b deploy/cf-dq-2026-08-18-freshness-wire

cp "$HOLIKA_ROOT/reference/code/cf-dq/main.py" "$REPO/cf-dq/main.py"

echo
echo "=== git diff --stat master (П4: обязан быть ровно один файл) ==="
git diff --stat master

echo
echo "=== .gcloudignore (cf-dq/) — проверка наличия и содержимого ==="
cat "$REPO/cf-dq/.gcloudignore" 2>&1 || echo "ОТСУТСТВУЕТ"

echo
echo "=== сплошной поиск секретов по диффу ==="
git diff -- cf-dq/main.py | grep -inE "secret|token|password|api[_-]?key|bearer|AIza|ya29\.|-----BEGIN" && echo "НАЙДЕНО (см. выше)" || echo "NO_MATCHES (пусто)"

echo
echo "=== git status ==="
git status

echo
echo "=== date -u (end) ==="
date -u
echo "=== gcloud auth list (end) ==="
gcloud auth list
