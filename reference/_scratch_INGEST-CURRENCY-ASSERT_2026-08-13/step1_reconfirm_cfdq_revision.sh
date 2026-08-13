#!/bin/bash
# Step 1 — read-only переподтверждение свежести reference/code/cf-dq/ против живой ревизии.
set -euo pipefail

date -u
gcloud auth list

echo "=== gcloud functions describe cf-dq ==="
gcloud functions describe cf-dq --gen2 --region=asia-east1 --project=msklad-bi-prod \
  --format="yaml(serviceConfig.revision,state,updateTime,buildConfig.source.storageSource)"

echo "=== sha256 живого снапшота в reference/code/cf-dq/ ==="
shasum -a 256 reference/code/cf-dq/main.py reference/code/cf-dq/config.py \
  reference/code/cf-dq/helpers.py reference/code/cf-dq/requirements.txt

echo "=== MANIFEST.md — зафиксированная последняя ревизия/sha256 (cf-dq-00009-coy) ==="
grep -A6 "^| Файл | sha256 (новый архив = ветка деплоя) |" reference/code/cf-dq/MANIFEST.md | tail -n +2

date -u
gcloud auth list
