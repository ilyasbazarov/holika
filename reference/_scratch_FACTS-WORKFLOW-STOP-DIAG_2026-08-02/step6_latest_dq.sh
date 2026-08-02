#!/usr/bin/env bash
set -euo pipefail

echo "=== date -u (start) ==="
date -u
echo "=== gcloud auth list (start) ==="
gcloud auth list

echo "=== Cloud Logging: последний (13:00Z) отказ hourly — DQ детали дословно ==="
gcloud logging read '
resource.type="workflows.googleapis.com/Workflow"
resource.labels.workflow_id="msklad-pipeline-hourly"
labels."workflows.googleapis.com/execution_id"="d022a76a-a81f-40b7-b997-86502f7f7482"
' --format=json --order=asc --limit=200

echo "=== date -u (end) ==="
date -u
echo "=== gcloud auth list (end) ==="
gcloud auth list
