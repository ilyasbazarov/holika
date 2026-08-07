#!/usr/bin/env bash
set -euo pipefail

SCRATCH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKDIR="${SCRATCH}/step7_work"
BRANCH_DIR="${SCRATCH}/branch_check/repo/cf-facts"
rm -rf "${WORKDIR}"
mkdir -p "${WORKDIR}/new"

echo "=== UTC anchor (start) ==="
date -u
echo "=== caller identity (start) ==="
gcloud auth list

echo "=== describe new cf-facts revision ==="
gcloud functions describe cf-facts --gen2 --region=asia-east1 --project=msklad-bi-prod --format=json \
  > "${WORKDIR}/cf-facts_describe_new.json"
cat "${WORKDIR}/cf-facts_describe_new.json"

REVISION="$(python3 -c 'import json; d=json.load(open("'"${WORKDIR}"'/cf-facts_describe_new.json")); print(d["serviceConfig"]["revision"])')"
GENERATION="$(python3 -c 'import json; d=json.load(open("'"${WORKDIR}"'/cf-facts_describe_new.json")); print(d["buildConfig"]["source"]["storageSource"]["generation"])')"
BUCKET="$(python3 -c 'import json; d=json.load(open("'"${WORKDIR}"'/cf-facts_describe_new.json")); print(d["buildConfig"]["source"]["storageSource"]["bucket"])')"
OBJECT="$(python3 -c 'import json; d=json.load(open("'"${WORKDIR}"'/cf-facts_describe_new.json")); print(d["buildConfig"]["source"]["storageSource"]["object"])')"

echo "=== resolved: revision=${REVISION} generation=${GENERATION} ==="

echo "=== download archive by pinned generation ==="
gcloud storage cp "gs://${BUCKET}/${OBJECT}#${GENERATION}" "${WORKDIR}/new/function-source.zip"

cd "${WORKDIR}/new"
unzip -o -q function-source.zip -d unpacked

echo "=== sha256 of new archive contents ==="
cd unpacked
find . -type f | sort | xargs shasum -a 256

echo "=== byte-compare: new archive vs pushed branch cf-facts/ ==="
diff -rq "${WORKDIR}/new/unpacked" "${BRANCH_DIR}" || true

echo "=== check for known junk classes ==="
find "${WORKDIR}/new/unpacked" -iname "*.bak" -o -iname "__pycache__" -o -iname ".DS_Store" -o -iname "src.zip" -o -iname "patch_*.py"
echo "(конец списка мусора, пусто = нет мусора)"

echo "=== UTC anchor (end) ==="
date -u
echo "=== caller identity (end) ==="
gcloud auth list

echo "=== workdir path (not cleaned up, ADR-043) ==="
echo "${WORKDIR}"
