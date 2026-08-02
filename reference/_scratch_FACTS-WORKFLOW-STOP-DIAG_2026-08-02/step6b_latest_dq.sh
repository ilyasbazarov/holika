#!/usr/bin/env bash
set -euo pipefail
echo "=== date -u (start) ==="; date -u
echo "=== gcloud auth list (start) ==="; gcloud auth list

echo "=== Cloud Logging: logName=Workflows, execution_id=d022a76a (13:00Z сегодня) ==="
gcloud logging read '
logName="projects/msklad-bi-prod/logs/Workflows"
labels.execution_id="d022a76a-a81f-40b7-b997-86502f7f7482"
' --format=json --order=asc --limit=50

echo "=== date -u (end) ==="; date -u
echo "=== gcloud auth list (end) ==="; gcloud auth list
