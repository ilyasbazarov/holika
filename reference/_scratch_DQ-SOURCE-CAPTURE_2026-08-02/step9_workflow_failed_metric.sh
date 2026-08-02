#!/bin/bash
set -euo pipefail
SCRATCH="reference/_scratch_DQ-SOURCE-CAPTURE_2026-08-02"

echo "=== date -u (start) ==="
date -u
echo "=== gcloud auth list (start) ==="
gcloud auth list

echo "=== metric msklad_workflow_execution_failed definition ==="
gcloud logging metrics describe msklad_workflow_execution_failed --project=msklad-bi-prod --format=json 2>&1

echo "=== metric msklad_workflow_execution_any definition ==="
gcloud logging metrics describe msklad_workflow_execution_any --project=msklad-bi-prod --format=json 2>&1

echo "=== date -u (end) ==="
date -u
echo "=== gcloud auth list (end) ==="
gcloud auth list
