#!/usr/bin/env bash
set -euo pipefail

echo "=== date -u (start) ==="
date -u
echo "=== gcloud auth list (start) ==="
gcloud auth list

echo "=== HOURLY: describe первого отказавшего выполнения (2026-08-01T18:00:02Z) ==="
gcloud workflows executions describe cfee49f6-18cb-40c8-83f1-a07d77737c66 \
  --workflow=msklad-pipeline-hourly --location=asia-east1 --format=json

echo "=== HOURLY: describe последнего успешного выполнения (2026-08-01T17:00:02Z) ==="
gcloud workflows executions describe bc08b99a-6456-460a-9591-4e0bfab0d0c6 \
  --workflow=msklad-pipeline-hourly --location=asia-east1 --format=json

echo "=== WEEKLY: describe первого отказавшего выполнения (2026-07-26T01:00:00Z) ==="
gcloud workflows executions describe 01f7d0b1-1922-4343-ae8b-d75c2f4c77ed \
  --workflow=msklad-pipeline-weekly --location=asia-east1 --format=json

echo "=== WEEKLY: describe последнего успешного выполнения (2026-07-19T01:00:00Z) ==="
gcloud workflows executions describe 3672708e-2389-4537-bf5d-c9273786f01c \
  --workflow=msklad-pipeline-weekly --location=asia-east1 --format=json

echo "=== Cloud Logging: логи cf-dq вокруг 2026-08-01T18:00-18:05Z (первый отказ hourly) ==="
gcloud logging read '
resource.type="cloud_run_revision"
resource.labels.service_name="cf-dq"
timestamp>="2026-08-01T17:59:00Z"
timestamp<="2026-08-01T18:05:00Z"
' --format=json --order=asc --limit=200

echo "=== Cloud Logging: логи workflow msklad-pipeline-hourly вокруг 2026-08-01T18:00-18:05Z ==="
gcloud logging read '
resource.type="workflows.googleapis.com/Workflow"
timestamp>="2026-08-01T17:59:00Z"
timestamp<="2026-08-01T18:05:00Z"
' --format=json --order=asc --limit=200

echo "=== date -u (end) ==="
date -u
echo "=== gcloud auth list (end) ==="
gcloud auth list
