#!/bin/bash
set -euo pipefail
echo "=== date -u (start) ==="
date -u
echo "=== gcloud auth list (start) ==="
gcloud auth list

echo "=== gcloud logging metrics update msklad_dq_gate_failed ==="
gcloud logging metrics update msklad_dq_gate_failed \
  --project=msklad-bi-prod \
  --log-filter='resource.type="workflows.googleapis.com/Workflow"
resource.labels.workflow_id=~"^msklad-pipeline"
severity>=CRITICAL
textPayload=~"DQ Gate FAILED"' \
  --description="DQ Gate провалил проверку качества данных"

echo "=== date -u (end) ==="
date -u
echo "=== gcloud auth list (end) ==="
gcloud auth list
