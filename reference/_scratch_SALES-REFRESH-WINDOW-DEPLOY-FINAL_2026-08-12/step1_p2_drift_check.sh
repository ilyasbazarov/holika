#!/usr/bin/env bash
set -euo pipefail

echo "=== UTC anchor (start) ==="
date -u
echo "=== gcloud auth (start) ==="
gcloud auth list

WORKDIR=$(mktemp -d)
cd "$WORKDIR"

echo "=== describe cf-facts ==="
gcloud functions describe cf-facts --gen2 --region=asia-east1 --project=msklad-bi-prod --format=json > describe.json
BUCKET=$(python3 -c "import json;print(json.load(open('describe.json'))['buildConfig']['source']['storageSource']['bucket'])")
OBJECT=$(python3 -c "import json;print(json.load(open('describe.json'))['buildConfig']['source']['storageSource']['object'])")
GEN=$(python3 -c "import json;print(json.load(open('describe.json'))['buildConfig']['source']['storageSource']['generation'])")
REV=$(python3 -c "import json;print(json.load(open('describe.json'))['serviceConfig']['revision'])")
echo "revision=$REV bucket=$BUCKET object=$OBJECT generation=$GEN"

gcloud storage cp "gs://${BUCKET}/${OBJECT}#${GEN}" ./archive.zip
mkdir extracted
cd extracted
unzip -q ../archive.zip

echo "=== sha256 archive vs master (holika-prod) ==="
MASTER=/Users/ilyasbazarov/Desktop/msklad_project/holika/worktrees/SALES-REFRESH-WINDOW-DEPLOY-FINAL/reference/_scratch_SALES-REFRESH-WINDOW-DEPLOY-FINAL_2026-08-12/holika-prod
for f in helpers.py bq_ops.py config.py main.py fetch_perimeter.py requirements.txt; do
  A=$(sha256sum "$f" 2>/dev/null | cut -d' ' -f1)
  B=$(git -C "$MASTER" show master:cf-facts/$f 2>/dev/null | sha256sum | cut -d' ' -f1)
  MATCH="MISMATCH"
  [ "$A" = "$B" ] && MATCH="match"
  echo "$f: archive=$A master=$B -> $MATCH"
done

echo "=== workdir path (printed, not cleaned — ADR-043) ==="
echo "$WORKDIR"

echo "=== UTC anchor (end) ==="
date -u
echo "=== gcloud auth (end) ==="
gcloud auth list
