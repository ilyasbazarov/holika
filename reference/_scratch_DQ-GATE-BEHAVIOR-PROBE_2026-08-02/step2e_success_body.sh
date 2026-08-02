#!/usr/bin/env bash
set -euo pipefail
echo "=== date -u (start) ==="
date -u
echo "=== gcloud auth list (start) ==="
gcloud auth list

echo "=== Все логи workflows.googleapis.com/Workflow с 'DQ Gate' в тексте, окно 2026-07-26T17:59:00Z..18:10:00Z ==="
gcloud logging read '
resource.type="workflows.googleapis.com/Workflow"
timestamp>="2026-07-26T17:59:00Z"
timestamp<="2026-07-26T18:10:00Z"
textPayload:"DQ Gate"
' --format=json --order=asc --limit=100

echo "=== date -u (end) ==="
date -u
echo "=== gcloud auth list (end) ==="
gcloud auth list
