#!/usr/bin/env bash
set -euo pipefail

echo "=== UTC anchor (start) ==="
date -u
echo "=== gcloud auth list (start) ==="
gcloud auth list

SCRATCH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$SCRATCH_DIR/holika-prod"
PROD_COMMIT=c9b967ffcae01ceeae3b6fd0e6e2cba0549ed738

cd "$REPO_DIR"

echo "--- П5: поиск секретов в диффе (печать совпавших строк с номерами, не только метка) ---"
git diff "$PROD_COMMIT" -- cf-dq/main.py > "$SCRATCH_DIR/step10_diff.txt"
grep -inE "bearer|msklad-token|api[_-]?key|secret|password|-----BEGIN" "$SCRATCH_DIR/step10_diff.txt" > "$SCRATCH_DIR/step10_secret_grep.txt" || true
echo "совпадений: $(wc -l < "$SCRATCH_DIR/step10_secret_grep.txt")"
cat "$SCRATCH_DIR/step10_secret_grep.txt"

echo "--- git diff --stat (ровно один файл, повторная фиксация) ---"
git diff --stat "$PROD_COMMIT"

echo "--- commit ---"
git add cf-dq/main.py
git commit -m "cf-dq: перенос блока CHECKS ниже определений (DQ-FRESHNESS-WIRE-CHECKS-ORDER); повторная попытка deploy 2 после NameError healthcheck-fail cf-dq-00010-kiq"

git log -1 --format="%H %ci %s"

echo "=== UTC anchor (end) ==="
date -u
echo "=== gcloud auth list (end) ==="
gcloud auth list
