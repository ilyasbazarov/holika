#!/usr/bin/env bash
set -euo pipefail

echo "=== UTC anchor (start) ==="
date -u
echo "=== caller identity (start) ==="
gcloud auth list

TOKEN="$(gcloud secrets versions access latest --secret=msklad-token --project=msklad-bi-prod)"

echo "=== step 1a: list one entity/retaildemand document ==="
LIST_JSON="$(curl -sS --compressed -H "Authorization: Bearer ${TOKEN}" \
  "https://api.moysklad.ru/api/remap/1.2/entity/retaildemand?limit=1")"
echo "${LIST_JSON}"

DOC_ID="$(echo "${LIST_JSON}" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d["rows"][0]["id"])')"
echo "=== resolved document id: ${DOC_ID} ==="

echo "=== step 1b: GET entity/retaildemand/${DOC_ID}/positions ==="
POS_JSON="$(curl -sS --compressed -H "Authorization: Bearer ${TOKEN}" \
  "https://api.moysklad.ru/api/remap/1.2/entity/retaildemand/${DOC_ID}/positions")"
echo "${POS_JSON}"

echo "=== UTC anchor (end) ==="
date -u
echo "=== caller identity (end) ==="
gcloud auth list
