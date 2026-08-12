#!/usr/bin/env bash
set -euo pipefail

echo "=== UTC anchor (start) ==="
date -u
echo "=== gcloud auth (start) ==="
gcloud auth list

TOKEN=$(gcloud secrets versions access latest --secret=msklad-token --project=msklad-bi-prod)

echo "=== GET entity/demand, filter moment 2026-05-24, limit=100 ==="
RESP=$(curl -s --compressed -G "https://api.moysklad.ru/api/remap/1.2/entity/demand" \
  --data-urlencode "filter=moment>=2026-05-24 00:00:00;moment<=2026-05-24 23:59:59" \
  --data-urlencode "limit=100" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Accept-Encoding: gzip")

echo "$RESP" > raw_response.json

echo "=== counts ==="
python3 -c "
import json
with open('raw_response.json') as f:
    d = json.load(f)
rows = d.get('rows', [])
meta = d.get('meta') or {}
meta_size = meta.get('size')
print(f'len(rows)={len(rows)}')
print(f'meta_size={meta_size}')
print(f'invariant len(rows)==meta_size: {len(rows) == meta_size}')
"

echo "=== UTC anchor (end) ==="
date -u
echo "=== gcloud auth (end) ==="
gcloud auth list
