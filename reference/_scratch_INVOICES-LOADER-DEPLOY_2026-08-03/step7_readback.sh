#!/usr/bin/env bash
set -euo pipefail
date -u
gcloud auth list

SCRATCH_DIR="$(cd "$(dirname "$0")" && pwd)"

gcloud functions describe cf-finance --gen2 --region=asia-east1 --project=msklad-bi-prod \
  --format=json > "${SCRATCH_DIR}/step7_describe_new.json"

REVISION=$(python3 -c "import json;print(json.load(open('${SCRATCH_DIR}/step7_describe_new.json'))['serviceConfig']['revision'])")
BUCKET_PATH=$(python3 -c "import json;print(json.load(open('${SCRATCH_DIR}/step7_describe_new.json'))['buildConfig']['source']['storageSource']['bucket'])")
OBJECT=$(python3 -c "import json;print(json.load(open('${SCRATCH_DIR}/step7_describe_new.json'))['buildConfig']['source']['storageSource']['object'])")
GENERATION=$(python3 -c "import json;print(json.load(open('${SCRATCH_DIR}/step7_describe_new.json'))['buildConfig']['source']['storageSource']['generation'])")

echo "revision=${REVISION}"
echo "generation=${GENERATION}"

mkdir -p "${SCRATCH_DIR}/deployed_source"
gsutil cp "gs://${BUCKET_PATH}/${OBJECT}#${GENERATION}" "${SCRATCH_DIR}/deployed_source.zip"
cd "${SCRATCH_DIR}/deployed_source"
unzip -o -q "../deployed_source.zip"
cd - > /dev/null

echo "=== sha256 развёрнутого архива ==="
find "${SCRATCH_DIR}/deployed_source" -type f | sort | xargs shasum -a 256

echo "=== sha256 ветки deploy/cf-finance-2026-08-03-invoices ==="
find "${SCRATCH_DIR}/holika-prod-master/cf-finance" -type f | sort | xargs shasum -a 256

echo "=== сверка ==="
python3 << 'PYEOF'
import hashlib, os

def sha(path):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        h.update(f.read())
    return h.hexdigest()

deployed_dir = "/Users/ilyasbazarov/Desktop/msklad_project/holika/worktrees/INVOICES-LOADER-DEPLOY/reference/_scratch_INVOICES-LOADER-DEPLOY_2026-08-03/deployed_source"
branch_dir = "/Users/ilyasbazarov/Desktop/msklad_project/holika/worktrees/INVOICES-LOADER-DEPLOY/reference/_scratch_INVOICES-LOADER-DEPLOY_2026-08-03/holika-prod-master/cf-finance"

deployed_files = {}
for root, _, files in os.walk(deployed_dir):
    for fn in files:
        p = os.path.join(root, fn)
        rel = os.path.relpath(p, deployed_dir)
        deployed_files[rel] = sha(p)

branch_files = {}
for root, _, files in os.walk(branch_dir):
    for fn in files:
        p = os.path.join(root, fn)
        rel = os.path.relpath(p, branch_dir)
        branch_files[rel] = sha(p)

all_names = sorted(set(deployed_files) | set(branch_files))
mismatch = False
junk_patterns = ('.bak', '__pycache__', 'patch_')
for name in all_names:
    d = deployed_files.get(name)
    b = branch_files.get(name)
    is_junk = any(p in name for p in junk_patterns)
    status = "СОВПАЛО" if d == b else ("ЛИШНЕЕ(мусор)" if is_junk and b is None else "НЕ СОВПАЛО/ОТСУТСТВУЕТ")
    if d != b and not is_junk:
        mismatch = True
    print(f"{status}  {name}  deployed={d}  branch={b}")

print()
print("МУСОР В АРХИВЕ:", "ЕСТЬ (не .bak/pycache/patch_ шаблон)" if any(
    (n not in branch_files) and not any(p in n for p in junk_patterns) for n in deployed_files
) else "НЕТ")
print("ВЕРДИКТ (только реальный код):", "РАСХОЖДЕНИЕ ЕСТЬ — ДЕПЛОЙ НЕУСПЕШЕН" if mismatch else "ВСЁ СОВПАЛО")
PYEOF

date -u
gcloud auth list
