#!/usr/bin/env bash
set -euo pipefail

SCRATCH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT="msklad-bi-prod"
REGION="asia-east1"
CF="cf-facts"

echo "=== UTC anchor (start) ==="
date -u
echo "=== auth identity (start) ==="
gcloud auth list

echo "=== gcloud functions describe ${CF} ==="
gcloud functions describe "${CF}" --gen2 --region="${REGION}" --project="${PROJECT}" \
  --format=json > "${SCRATCH}/cf-facts_describe.json"

REVISION=$(python3 -c "import json;print(json.load(open('${SCRATCH}/cf-facts_describe.json'))['serviceConfig']['revision'])")
BUCKET=$(python3 -c "import json;print(json.load(open('${SCRATCH}/cf-facts_describe.json'))['buildConfig']['source']['storageSource']['bucket'])")
OBJECT=$(python3 -c "import json;print(json.load(open('${SCRATCH}/cf-facts_describe.json'))['buildConfig']['source']['storageSource']['object'])")
GENERATION=$(python3 -c "import json;print(json.load(open('${SCRATCH}/cf-facts_describe.json'))['buildConfig']['source']['storageSource']['generation'])")

echo "revision=${REVISION}"
echo "bucket=${BUCKET}"
echo "object=${OBJECT}"
echo "generation=${GENERATION}"

echo "=== download pinned archive ==="
mkdir -p "${SCRATCH}/live_archive"
gcloud storage cp "gs://${BUCKET}/${OBJECT}#${GENERATION}" "${SCRATCH}/live_archive/function-source.zip"
cd "${SCRATCH}/live_archive"
unzip -o function-source.zip -d unpacked > /dev/null
echo "=== sha256 live archive (cf-facts/*.py, config.py, requirements.txt) ==="
( cd unpacked && find . -maxdepth 1 -type f \( -name "*.py" -o -name "requirements.txt" \) -print0 | sort -z | xargs -0 shasum -a 256 )

echo "=== clone holika-prod master ==="
cd "${SCRATCH}"
rm -rf holika-prod
git clone --quiet --branch master https://github.com/ilyasbazarov/holika-prod.git
echo "=== master HEAD ==="
git -C holika-prod rev-parse HEAD
echo "=== sha256 master cf-facts/ ==="
( cd holika-prod/cf-facts && find . -maxdepth 1 -type f \( -name "*.py" -o -name "requirements.txt" \) -print0 | sort -z | xargs -0 shasum -a 256 )

echo "=== auth identity (end) ==="
gcloud auth list
echo "=== UTC anchor (end) ==="
date -u

echo "SCRATCH_PATH=${SCRATCH}"
