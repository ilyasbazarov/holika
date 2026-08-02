#!/usr/bin/env bash
set -euo pipefail
echo "=== date -u (start) ==="
date -u
echo "=== gcloud auth list (start) ==="
gcloud auth list

echo "=== Workflow-логи (ЛЮБОЙ severity) вокруг успешного прогона 2026-07-26T18:00:02Z..18:03Z ==="
gcloud logging read '
resource.type="workflows.googleapis.com/Workflow"
timestamp>="2026-07-26T17:59:30Z"
timestamp<="2026-07-26T18:03:00Z"
' --format=json --order=asc --limit=100

echo "=== date -u (end) ==="
date -u
echo "=== gcloud auth list (end) ==="
gcloud auth list
