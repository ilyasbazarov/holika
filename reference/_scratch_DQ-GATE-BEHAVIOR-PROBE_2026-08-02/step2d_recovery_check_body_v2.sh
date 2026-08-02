#!/usr/bin/env bash
set -euo pipefail

echo "=== date -u (start) ==="
date -u
echo "=== gcloud auth list (start) ==="
gcloud auth list

echo "=== Cloud Logging: logName=Workflows, окно 2026-07-26T17:59:00Z..18:03:00Z (ПЕРВОЕ восстановившееся выполнение) ==="
gcloud logging read '
logName="projects/msklad-bi-prod/logs/Workflows"
timestamp>="2026-07-26T17:59:00Z"
timestamp<="2026-07-26T18:03:00Z"
' --format=json --order=asc --limit=200

echo "=== Cloud Logging: logName=Workflows, окно 2026-07-26T16:59:00Z..17:03:00Z (ПОСЛЕДНЕЕ FAILED выполнение блока, для сравнения) ==="
gcloud logging read '
logName="projects/msklad-bi-prod/logs/Workflows"
timestamp>="2026-07-26T16:59:00Z"
timestamp<="2026-07-26T17:03:00Z"
' --format=json --order=asc --limit=200

echo "=== date -u (end) ==="
date -u
echo "=== gcloud auth list (end) ==="
gcloud auth list
