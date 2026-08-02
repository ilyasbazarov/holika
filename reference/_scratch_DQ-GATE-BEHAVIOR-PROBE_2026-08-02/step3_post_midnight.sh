#!/usr/bin/env bash
set -euo pipefail
echo "=== date -u (start) ==="
date -u
echo "=== gcloud auth list (start) ==="
gcloud auth list

echo "=== Workflow-логи (severity=CRITICAL, DQ Gate FAILED) вокруг первого прогона ПОСЛЕ 2026-08-02T18:00Z (полночь Бишкек) ==="
gcloud logging read '
resource.type="workflows.googleapis.com/Workflow"
severity=CRITICAL
timestamp>="2026-08-02T17:59:00Z"
timestamp<="2026-08-02T20:05:00Z"
' --format=json --order=asc --limit=50

echo "=== date -u (end) ==="
date -u
echo "=== gcloud auth list (end) ==="
gcloud auth list
