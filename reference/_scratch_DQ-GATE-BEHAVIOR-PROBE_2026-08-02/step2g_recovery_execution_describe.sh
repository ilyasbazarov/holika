#!/usr/bin/env bash
set -euo pipefail
echo "=== date -u (start) ==="
date -u
echo "=== gcloud auth list (start) ==="
gcloud auth list

echo "=== describe восстанавливающего выполнения cdf2cea8-1a3b-4bdc-b174-a5d2b21c4e91 (2026-07-26T18:00:02Z, первый SUCCEEDED после блока) ==="
gcloud workflows executions describe cdf2cea8-1a3b-4bdc-b174-a5d2b21c4e91 --workflow=msklad-pipeline-hourly --location=asia-east1 --format=json

echo "=== describe последнего FAILED перед восстановлением (2026-07-26T17:00:02Z) ==="
gcloud workflows executions list msklad-pipeline-hourly --location=asia-east1 --limit=520 --format=json > /tmp/all_execs.json 2>&1 || true

echo "=== date -u (end) ==="
date -u
echo "=== gcloud auth list (end) ==="
gcloud auth list
