#!/usr/bin/env bash
set -euo pipefail

echo "=== UTC anchor (start) ==="
date -u
echo "=== gcloud auth list (start) ==="
gcloud auth list

SCRATCH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$SCRATCH_DIR/holika-prod"

echo "=== clone code-repo ==="
rm -rf "$REPO_DIR"
git clone https://github.com/ilyasbazarov/holika-prod.git "$REPO_DIR"
cd "$REPO_DIR"
git fetch origin

echo "=== целевые sha256 (обслуживающая ревизия cf-dq-00009-coy, генерация 1786561996565446) ==="
echo "main.py:         477c216ceaa3623a2f254129673413e9697b50bcd263c2451bd0334eb5486e67"
echo "config.py:       360d0a195abc0bc53ad8bb59ce292bf6b7045486169fcc466dd4d6636ff0a756"
echo "helpers.py:      0f335877c29d9c18c5e8d9617ab38768c6d2ba01986d178abaff92d4ce9dd146"
echo "requirements.txt:587133daa6a4c31e57bfd84c371ea4d6e0831e69ed66babf12c15dbebfd6b516"

echo "=== история cf-dq/main.py: все коммиты, тронувшие файл ==="
git log --format="%H %ci %s" -- cf-dq/main.py > "$SCRATCH_DIR/step5_main_py_history.txt"
cat "$SCRATCH_DIR/step5_main_py_history.txt"

echo "=== перебор: sha256 cf-dq/main.py на каждом коммите истории ==="
: > "$SCRATCH_DIR/step5_sha_by_commit.txt"
while read -r COMMIT REST; do
  SHA=$(git show "${COMMIT}:cf-dq/main.py" 2>/dev/null | shasum -a 256 | awk '{print $1}')
  echo "$COMMIT $SHA" | tee -a "$SCRATCH_DIR/step5_sha_by_commit.txt"
done < <(git log --format="%H" -- cf-dq/main.py)

echo "=== найденный коммит(ы), совпадающий с обслуживающей ревизией ==="
grep "477c216ceaa3623a2f254129673413e9697b50bcd263c2451bd0334eb5486e67" "$SCRATCH_DIR/step5_sha_by_commit.txt" || echo "НЕ НАЙДЕНО прямым совпадением на изменяющих коммитах"

echo "=== UTC anchor (end) ==="
date -u
echo "=== gcloud auth list (end) ==="
gcloud auth list
