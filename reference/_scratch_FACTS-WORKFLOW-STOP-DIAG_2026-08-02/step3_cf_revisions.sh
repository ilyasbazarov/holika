#!/usr/bin/env bash
set -euo pipefail

echo "=== date -u (start) ==="
date -u
echo "=== gcloud auth list (start) ==="
gcloud auth list

echo "=== cf-facts: functions describe (region asia-east1) ==="
gcloud functions describe cf-facts --region=asia-east1 --gen2 --format=json || echo "describe FAILED, fallback list"
gcloud functions list --filter="name:cf-facts" --format=json

echo "=== cf-facts: run services describe (revision/updateTime детально) ==="
gcloud run services describe cf-facts --region=asia-east1 --format=json

echo "=== cf-dq: functions describe (region asia-east1) ==="
gcloud functions describe cf-dq --region=asia-east1 --gen2 --format=json || echo "describe FAILED, fallback list"
gcloud functions list --filter="name:cf-dq" --format=json

echo "=== cf-dq: run services describe (revision/updateTime детально) ==="
gcloud run services describe cf-dq --region=asia-east1 --format=json

echo "=== cf-dq: список ревизий Cloud Run (история деплоев) ==="
gcloud run revisions list --service=cf-dq --region=asia-east1 --format=json

echo "=== cf-facts: список ревизий Cloud Run (история деплоев) ==="
gcloud run revisions list --service=cf-facts --region=asia-east1 --format=json

echo "=== date -u (end) ==="
date -u
echo "=== gcloud auth list (end) ==="
gcloud auth list
