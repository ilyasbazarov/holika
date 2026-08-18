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

echo "=== П3 полная сверка: все четыре файла архива против прод-коммита ==="
ALL_MATCH=1
check_one() {
  local f="$1" archive_sha="$2"
  local commit_sha
  commit_sha=$(git show "${PROD_COMMIT}:cf-dq/${f}" 2>/dev/null | shasum -a 256 | awk '{print $1}')
  if [ "$commit_sha" = "$archive_sha" ]; then
    printf '%-20s archive=%s commit=%s MATCH\n' "$f" "$archive_sha" "$commit_sha"
  else
    printf '%-20s archive=%s commit=%s MISMATCH\n' "$f" "$archive_sha" "$commit_sha"
    ALL_MATCH=0
  fi
}
check_one main.py          477c216ceaa3623a2f254129673413e9697b50bcd263c2451bd0334eb5486e67
check_one config.py        360d0a195abc0bc53ad8bb59ce292bf6b7045486169fcc466dd4d6636ff0a756
check_one helpers.py       0f335877c29d9c18c5e8d9617ab38768c6d2ba01986d178abaff92d4ce9dd146
check_one requirements.txt 587133daa6a4c31e57bfd84c371ea4d6e0831e69ed66babf12c15dbebfd6b516
echo "ALL_MATCH=$ALL_MATCH"

echo "=== какие ветки содержат прод-коммит ==="
git branch -a --contains "$PROD_COMMIT"

echo "=== is-ancestor: прод-коммит -> origin/master ==="
if git merge-base --is-ancestor "$PROD_COMMIT" origin/master; then
  echo "TRUE: $PROD_COMMIT является предком origin/master"
else
  echo "FALSE: $PROD_COMMIT НЕ является предком origin/master"
fi

echo "=== head master (для сравнения) ==="
git log -1 --format="%H %ci %s" origin/master

echo "=== есть ли коммиты между прод-коммитом и master, трогающие cf-dq/ ==="
git log --format="%H %ci %s" "${PROD_COMMIT}..origin/master" -- cf-dq/ || true

echo "=== UTC anchor (end) ==="
date -u
echo "=== gcloud auth list (end) ==="
gcloud auth list
