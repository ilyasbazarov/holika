#!/bin/bash
set -uo pipefail
echo "=== date -u (start) ==="
date -u
echo "=== gcloud auth list (start) ==="
gcloud auth list

echo "=== read-back: logging metrics list (filter for msklad_dq_gate_failed) ==="
gcloud logging metrics list --project=msklad-bi-prod --format=yaml | sed -n '/^name: msklad_dq_gate_failed$/,/^---$/p'

echo "=== control read on real event with LIVE metric filter (via logging read, same text) ==="
gcloud logging read '
resource.type="workflows.googleapis.com/Workflow"
resource.labels.workflow_id=~"^msklad-pipeline"
severity>=CRITICAL
textPayload=~"DQ Gate FAILED"
timestamp>="2026-08-01T18:00:00Z"
timestamp<="2026-08-01T18:10:00Z"
' --project=msklad-bi-prod --format=json --limit=5

echo "=== date -u (end) ==="
date -u
echo "=== gcloud auth list (end) ==="
gcloud auth list
