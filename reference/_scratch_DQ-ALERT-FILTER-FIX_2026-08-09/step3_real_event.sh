#!/bin/bash
set -uo pipefail
echo "=== date -u (start) ==="
date -u
echo "=== gcloud auth list (start) ==="
gcloud auth list

echo "=== raw log entry at/near 2026-08-01T18:02:01Z, resource=Workflow, severity=CRITICAL ==="
gcloud logging read '
resource.type="workflows.googleapis.com/Workflow"
severity=CRITICAL
timestamp>="2026-08-01T18:00:00Z"
timestamp<="2026-08-01T18:10:00Z"
' --project=msklad-bi-prod --format=json --limit=20

echo "=== date -u (end) ==="
date -u
echo "=== gcloud auth list (end) ==="
gcloud auth list
