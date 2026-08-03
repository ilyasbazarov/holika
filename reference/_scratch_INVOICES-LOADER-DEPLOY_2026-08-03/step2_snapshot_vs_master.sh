#!/usr/bin/env bash
set -euo pipefail

date -u
gcloud auth list

SCRATCH="$(dirname "$0")"
CLONE_DIR="${SCRATCH}/holika-prod-master"

echo "=== describe cf-finance (живая ревизия) ==="
gcloud functions describe cf-finance --gen2 --region=asia-east1 --project=msklad-bi-prod \
  --format=json > "${SCRATCH}/step2_cf_finance_describe.json"

REVISION=$(python3 -c "import json;print(json.load(open('${SCRATCH}/step2_cf_finance_describe.json'))['serviceConfig']['revision'])")
BUCKET_PATH=$(python3 -c "import json;print(json.load(open('${SCRATCH}/step2_cf_finance_describe.json'))['buildConfig']['source']['storageSource']['bucket'])")
OBJECT=$(python3 -c "import json;print(json.load(open('${SCRATCH}/step2_cf_finance_describe.json'))['buildConfig']['source']['storageSource']['object'])")
GENERATION=$(python3 -c "import json;print(json.load(open('${SCRATCH}/step2_cf_finance_describe.json'))['buildConfig']['source']['storageSource']['generation'])")

echo "revision=${REVISION}"
echo "bucket=${BUCKET_PATH} object=${OBJECT} generation=${GENERATION}"

echo "=== скачивание архива живой ревизии ==="
mkdir -p "${SCRATCH}/live_source"
gsutil cp "gs://${BUCKET_PATH}/${OBJECT}#${GENERATION}" "${SCRATCH}/live_source.zip"
cd "${SCRATCH}/live_source"
unzip -o -q "../live_source.zip"
cd - > /dev/null

echo "=== sha256 живого архива по файлам ==="
find "${SCRATCH}/live_source" -type f | sort | xargs shasum -a 256

echo "=== клонирование master код-репо ==="
rm -rf "${CLONE_DIR}"
git clone --branch master --single-branch https://github.com/ilyasbazarov/holika-prod.git "${CLONE_DIR}"

echo "=== HEAD master ==="
git -C "${CLONE_DIR}" rev-parse HEAD

echo "=== sha256 cf-finance/ в master ==="
find "${CLONE_DIR}/cf-finance" -type f | sort | xargs shasum -a 256

echo "=== ПОБАЙТОВАЯ СВЕРКА (по имени файла, живой архив против master) ==="
python3 << 'PYEOF'
import hashlib, os, sys

def sha(path):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        h.update(f.read())
    return h.hexdigest()

scratch = os.path.dirname(os.environ.get("SCRIPT_PATH", "."))
live_dir = "/Users/ilyasbazarov/Desktop/msklad_project/holika/worktrees/INVOICES-LOADER-DEPLOY/reference/_scratch_INVOICES-LOADER-DEPLOY_2026-08-03/live_source"
master_dir = "/Users/ilyasbazarov/Desktop/msklad_project/holika/worktrees/INVOICES-LOADER-DEPLOY/reference/_scratch_INVOICES-LOADER-DEPLOY_2026-08-03/holika-prod-master/cf-finance"

live_files = {}
for root, _, files in os.walk(live_dir):
    for fn in files:
        p = os.path.join(root, fn)
        rel = os.path.relpath(p, live_dir)
        live_files[rel] = sha(p)

master_files = {}
for root, _, files in os.walk(master_dir):
    if ".git" in root:
        continue
    for fn in files:
        p = os.path.join(root, fn)
        rel = os.path.relpath(p, master_dir)
        master_files[rel] = sha(p)

all_names = sorted(set(live_files) | set(master_files))
mismatch = False
for name in all_names:
    l = live_files.get(name)
    m = master_files.get(name)
    status = "СОВПАЛО" if l == m else "НЕ СОВПАЛО/ОТСУТСТВУЕТ"
    if l != m:
        mismatch = True
    print(f"{status}  {name}  live={l}  master={m}")

print()
print("ВЕРДИКТ:", "РАСХОЖДЕНИЕ ЕСТЬ — СТОП" if mismatch else "ВСЁ СОВПАЛО")
PYEOF

date -u
gcloud auth list
