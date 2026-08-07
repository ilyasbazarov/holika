#!/usr/bin/env bash
set -euo pipefail

SCRATCH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKDIR="${SCRATCH}/step2_work"
rm -rf "${WORKDIR}"
mkdir -p "${WORKDIR}/live" "${WORKDIR}/master_repo"

echo "=== UTC anchor (start) ==="
date -u
echo "=== caller identity (start) ==="
gcloud auth list

echo "=== describe live cf-facts revision ==="
gcloud functions describe cf-facts --gen2 --region=asia-east1 --project=msklad-bi-prod --format=json \
  > "${WORKDIR}/cf-facts_describe.json"
cat "${WORKDIR}/cf-facts_describe.json"

REVISION="$(python3 -c 'import json; d=json.load(open("'"${WORKDIR}"'/cf-facts_describe.json")); print(d["serviceConfig"]["revision"])')"
GENERATION="$(python3 -c 'import json; d=json.load(open("'"${WORKDIR}"'/cf-facts_describe.json")); print(d["buildConfig"]["source"]["storageSource"]["generation"])')"
BUCKET="$(python3 -c 'import json; d=json.load(open("'"${WORKDIR}"'/cf-facts_describe.json")); print(d["buildConfig"]["source"]["storageSource"]["bucket"])')"
OBJECT="$(python3 -c 'import json; d=json.load(open("'"${WORKDIR}"'/cf-facts_describe.json")); print(d["buildConfig"]["source"]["storageSource"]["object"])')"
UPDATETIME="$(python3 -c 'import json; d=json.load(open("'"${WORKDIR}"'/cf-facts_describe.json")); print(d.get("updateTime",""))')"

echo "=== resolved: revision=${REVISION} generation=${GENERATION} bucket=${BUCKET} object=${OBJECT} updateTime=${UPDATETIME} ==="

echo "=== download archive by pinned generation ==="
gcloud storage cp "gs://${BUCKET}/${OBJECT}#${GENERATION}" "${WORKDIR}/live/function-source.zip"

echo "=== unpack ==="
cd "${WORKDIR}/live"
unzip -o -q function-source.zip -d unpacked

echo "=== sha256 of live archive contents ==="
cd unpacked
find . -type f | sort | xargs shasum -a 256

echo "=== clone master branch of code-repo ==="
cd "${WORKDIR}/master_repo"
git clone --quiet --branch master https://github.com/ilyasbazarov/holika-prod.git repo
MASTER_SHA="$(git -C repo rev-parse HEAD)"
echo "master HEAD: ${MASTER_SHA}"

echo "=== sha256 of master cf-facts/ contents ==="
cd repo/cf-facts
find . -type f | sort | xargs shasum -a 256

echo "=== byte-compare: live unpacked vs master cf-facts/ (excluding known deploy artifact naming) ==="
diff -rq "${WORKDIR}/live/unpacked" "${WORKDIR}/master_repo/repo/cf-facts" || true

echo "=== expected baseline check (brief input 4): revision=cf-facts-00008-zen generation=1786093276804812 ==="
echo "actual revision=${REVISION} generation=${GENERATION}"

echo "=== UTC anchor (end) ==="
date -u
echo "=== caller identity (end) ==="
gcloud auth list

echo "=== workdir path (not cleaned up, ADR-043) ==="
echo "${WORKDIR}"
