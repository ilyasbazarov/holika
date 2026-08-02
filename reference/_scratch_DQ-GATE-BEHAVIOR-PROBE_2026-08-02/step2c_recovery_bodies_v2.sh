#!/usr/bin/env bash
set -euo pipefail

echo "=== date -u (start) ==="
date -u
echo "=== gcloud auth list (start) ==="
gcloud auth list

echo "=== Workflow-логи (severity=CRITICAL, DQ Gate FAILED) вокруг 2026-07-21T17:00-18:03Z ==="
gcloud logging read '
resource.type="workflows.googleapis.com/Workflow"
severity=CRITICAL
timestamp>="2026-07-21T16:59:00Z"
timestamp<="2026-07-21T18:03:00Z"
' --format=json --order=asc --limit=50

echo "=== Workflow-логи (severity=CRITICAL) вокруг 2026-07-25T18:00Z..2026-07-26T18:03Z (ключевой кейс) ==="
gcloud logging read '
resource.type="workflows.googleapis.com/Workflow"
severity=CRITICAL
timestamp>="2026-07-25T17:59:00Z"
timestamp<="2026-07-26T18:03:00Z"
' --format=json --order=asc --limit=100

echo "=== Workflow-логи (severity=CRITICAL) вокруг 2026-07-28T20:00Z..21:03Z ==="
gcloud logging read '
resource.type="workflows.googleapis.com/Workflow"
severity=CRITICAL
timestamp>="2026-07-28T19:59:00Z"
timestamp<="2026-07-28T21:03:00Z"
' --format=json --order=asc --limit=50

echo "=== date -u (end) ==="
date -u
echo "=== gcloud auth list (end) ==="
gcloud auth list
