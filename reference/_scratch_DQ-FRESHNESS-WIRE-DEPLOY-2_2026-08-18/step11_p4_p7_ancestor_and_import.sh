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

echo "--- П4: is-ancestor(прод-коммит, HEAD ветки деплоя) ---"
if git merge-base --is-ancestor "$PROD_COMMIT" HEAD; then
  echo "TRUE: $PROD_COMMIT является предком HEAD ветки деплоя"
else
  echo "FALSE — СТОП"
  exit 1
fi

echo "--- П7: факт-проверка исполнением, каталог ВЕТКИ ДЕПЛОЯ (не снапшот reference/code/) ---"
/opt/homebrew/opt/python@3.14/bin/python3.14 --version

set +e
/opt/homebrew/opt/python@3.14/bin/python3.14 - "$REPO_DIR/cf-dq" <<'PYEOF'
import sys, os, types
from datetime import datetime, timezone

print(f"date -u (старт факт-проверки): {datetime.now(timezone.utc).isoformat()}")
print(f"интерпретатор: {sys.version}")

CF_DQ_DIR = os.path.abspath(sys.argv[1])
print(f"каталог проверки (ветка деплоя, код-репо): {CF_DQ_DIR}")
sys.path.insert(0, CF_DQ_DIR)

class _Permissive:
    def __getattr__(self, name): return _Permissive()
    def __call__(self, *a, **kw): return _Permissive()
    def __iter__(self): return iter(())
    def __getitem__(self, k): return _Permissive()

def _stub_module(name):
    mod = types.ModuleType(name)
    mod.__getattr__ = lambda attr: _Permissive()
    return mod

for modname in ["google", "google.cloud", "google.cloud.bigquery", "functions_framework"]:
    sys.modules[modname] = _stub_module(modname)
sys.modules["google"].cloud = sys.modules["google.cloud"]
sys.modules["google.cloud"].bigquery = sys.modules["google.cloud.bigquery"]
sys.modules["functions_framework"].http = lambda fn: fn

try:
    import main
    print("ok   импорт main")
    print(f"len(CHECKS)={len(main.CHECKS)}")
    rc = 0 if len(main.CHECKS) == 19 else 1
except Exception as e:
    print(f"FAIL импорт main: {type(e).__name__}: {e}")
    rc = 1

print(f"date -u (конец факт-проверки): {datetime.now(timezone.utc).isoformat()}")
sys.exit(rc)
PYEOF
IMPORT_RC=$?
set -e
echo "import_check rc=$IMPORT_RC"
if [ "$IMPORT_RC" -ne 0 ]; then
  echo "П7 ПРОВАЛЕН — СТОП, деплой не исполняется"
  exit 1
fi
echo "П7 пройден"

echo "=== UTC anchor (end) ==="
date -u
echo "=== gcloud auth list (end) ==="
gcloud auth list
