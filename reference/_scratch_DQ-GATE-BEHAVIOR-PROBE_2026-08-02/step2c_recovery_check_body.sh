#!/usr/bin/env bash
set -euo pipefail

echo "=== date -u (start) ==="
date -u
echo "=== gcloud auth list (start) ==="
gcloud auth list

echo "=== Cloud Logging: логи cf-dq вокруг ПЕРВОГО восстановившегося выполнения hourly (2026-07-26T18:00:02Z, execution cdf2cea8-1a3b-4bdc-b174-a5d2b21c4e91) ==="
gcloud logging read '
resource.type="cloud_run_revision"
resource.labels.service_name="cf-dq"
timestamp>="2026-07-26T17:59:00Z"
timestamp<="2026-07-26T18:05:00Z"
' --format=json --order=asc --limit=200

echo "=== Cloud Logging: логи workflow msklad-pipeline-hourly вокруг того же момента ==="
gcloud logging read '
resource.type="workflows.googleapis.com/Workflow"
labels."workflows.googleapis.com/execution_id"="cdf2cea8-1a3b-4bdc-b174-a5d2b21c4e91"
' --format=json --order=asc --limit=200

echo "=== Тело провала drift_check в ПОСЛЕДНЕМ FAILED выполнении блока (2026-07-26T17:00:02Z, execution 018262cd-0f50-4787-abc9-1fc85c454a58) — для сравнения yesterday_rev/ma7 непосредственно ДО восстановления ==="
gcloud logging read '
resource.type="cloud_run_revision"
resource.labels.service_name="cf-dq"
timestamp>="2026-07-26T16:59:00Z"
timestamp<="2026-07-26T17:05:00Z"
' --format=json --order=asc --limit=200

echo "=== date -u (end) ==="
date -u
echo "=== gcloud auth list (end) ==="
gcloud auth list
