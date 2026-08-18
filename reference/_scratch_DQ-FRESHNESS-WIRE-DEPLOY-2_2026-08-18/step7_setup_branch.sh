#!/usr/bin/env bash
set -euo pipefail

echo "=== UTC anchor (start) ==="
date -u
echo "=== gcloud auth list (start) ==="
gcloud auth list

SCRATCH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$SCRATCH_DIR/holika-prod"

PROD_COMMIT=c9b967ffcae01ceeae3b6fd0e6e2cba0549ed738
BRANCH=deploy/cf-dq-2026-08-18-freshness-wire-v2

cd "$REPO_DIR"
git fetch origin

echo "--- verify prod-commit exists ---"
git cat-file -t "$PROD_COMMIT"
git log -1 --format="%H %ci %s" "$PROD_COMMIT"

echo "--- create branch from prod-commit ---"
git checkout -b "$BRANCH" "$PROD_COMMIT"
git log -1 --format="HEAD now: %H"

echo "--- confirm HEAD equals prod-commit exactly (before any patch) ---"
if [ "$(git rev-parse HEAD)" = "$(git rev-parse "$PROD_COMMIT")" ]; then
  echo "OK: HEAD == $PROD_COMMIT"
else
  echo "MISMATCH: HEAD != $PROD_COMMIT"
  exit 1
fi

echo "--- П6 (предварительно): .gcloudignore в cf-dq/ (или общий) ---"
find . -iname ".gcloudignore" | sort
for f in $(find . -iname ".gcloudignore"); do
  echo "--- $f ---"
  cat "$f"
done

echo "--- П6 (предварительно): patch_dq.py в этом дереве? ---"
find cf-dq -type f | sort

echo "=== UTC anchor (end) ==="
date -u
echo "=== gcloud auth list (end) ==="
gcloud auth list
