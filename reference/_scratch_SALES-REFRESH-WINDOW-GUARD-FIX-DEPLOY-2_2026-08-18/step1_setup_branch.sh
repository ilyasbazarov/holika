#!/usr/bin/env bash
set -euo pipefail

echo "=== UTC anchor (start) ==="
date -u
echo "=== gcloud auth list (start) ==="
gcloud auth list

SCRATCH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$SCRATCH_DIR/holika-prod"

echo "=== Step 1: clone code-repo, create deploy branch from base 543b6c1 ==="
rm -rf "$REPO_DIR"
git clone https://github.com/ilyasbazarov/holika-prod.git "$REPO_DIR"

cd "$REPO_DIR"
git fetch origin

BASE_COMMIT=543b6c1
BRANCH=deploy/cf-facts-2026-08-18-guard-fix-f3-v2

echo "--- verify base commit exists ---"
git cat-file -t "$BASE_COMMIT"
git log -1 --format="%H %ci %s" "$BASE_COMMIT"

echo "--- create branch from base ---"
git checkout -b "$BRANCH" "$BASE_COMMIT"
git log -1 --format="HEAD now: %H"

echo "--- confirm HEAD equals base commit exactly (before any patch) ---"
if [ "$(git rev-parse HEAD)" = "$(git rev-parse "$BASE_COMMIT")" ]; then
  echo "OK: HEAD == $BASE_COMMIT"
else
  echo "MISMATCH: HEAD != $BASE_COMMIT"
  exit 1
fi

echo "=== UTC anchor (end) ==="
date -u
echo "=== gcloud auth list (end) ==="
gcloud auth list
