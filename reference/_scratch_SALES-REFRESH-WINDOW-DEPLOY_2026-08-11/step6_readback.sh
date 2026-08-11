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

echo "=== gcloud functions describe (post-deploy) ==="
gcloud functions describe "${CF}" --gen2 --region="${REGION}" --project="${PROJECT}" \
  --format=json > "${SCRATCH}/cf-facts_describe_postdeploy.json"

REVISION=$(python3 -c "import json;print(json.load(open('${SCRATCH}/cf-facts_describe_postdeploy.json'))['serviceConfig']['revision'])")
BUCKET=$(python3 -c "import json;print(json.load(open('${SCRATCH}/cf-facts_describe_postdeploy.json'))['buildConfig']['source']['storageSource']['bucket'])")
OBJECT=$(python3 -c "import json;print(json.load(open('${SCRATCH}/cf-facts_describe_postdeploy.json'))['buildConfig']['source']['storageSource']['object'])")
GENERATION=$(python3 -c "import json;print(json.load(open('${SCRATCH}/cf-facts_describe_postdeploy.json'))['buildConfig']['source']['storageSource']['generation'])")

echo "revision=${REVISION}"
echo "generation=${GENERATION}"

mkdir -p "${SCRATCH}/postdeploy_archive"
gcloud storage cp "gs://${BUCKET}/${OBJECT}#${GENERATION}" "${SCRATCH}/postdeploy_archive/function-source.zip"
cd "${SCRATCH}/postdeploy_archive"
unzip -o function-source.zip -d unpacked > /dev/null

echo "=== full file listing of deployed archive ==="
( cd unpacked && find . -type f | sort )

echo "=== sha256 of deployed archive (all files) ==="
( cd unpacked && find . -type f -print0 | sort -z | xargs -0 shasum -a 256 )

echo "=== sha256 of deploy branch cf-facts/ (source of truth) ==="
( cd "${SCRATCH}/holika-prod/cf-facts" && find . -maxdepth 1 -type f -print0 | sort -z | xargs -0 shasum -a 256 )

echo "=== auth identity (end) ==="
gcloud auth list
echo "=== UTC anchor (end) ==="
date -u
