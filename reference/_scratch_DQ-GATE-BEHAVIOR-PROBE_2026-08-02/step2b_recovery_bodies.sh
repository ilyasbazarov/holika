#!/usr/bin/env bash
set -euo pipefail

echo "=== date -u (start) ==="
date -u
echo "=== gcloud auth list (start) ==="
gcloud auth list

echo "=== cf-dq лог вокруг короткого разрыва 2026-07-21T17:00-18:01Z (FAILED->SUCCEEDED за 1 час) ==="
gcloud logging read '
resource.type="cloud_run_revision"
resource.labels.service_name="cf-dq"
timestamp>="2026-07-21T16:59:00Z"
timestamp<="2026-07-21T18:03:00Z"
' --format=json --order=asc --limit=200

echo "=== cf-dq лог вокруг разрыва 2026-07-25T18:00Z..2026-07-26T18:03Z (FAILED->SUCCEEDED за 24ч, ключевой кейс противоречия) ==="
gcloud logging read '
resource.type="cloud_run_revision"
resource.labels.service_name="cf-dq"
timestamp>="2026-07-25T17:59:00Z"
timestamp<="2026-07-26T18:03:00Z"
' --format=json --order=asc --limit=400

echo "=== cf-dq лог вокруг разрыва 2026-07-28T20:00Z..21:03Z (FAILED->SUCCEEDED за 1 час) ==="
gcloud logging read '
resource.type="cloud_run_revision"
resource.labels.service_name="cf-dq"
timestamp>="2026-07-28T19:59:00Z"
timestamp<="2026-07-28T21:03:00Z"
' --format=json --order=asc --limit=200

echo "=== date -u (end) ==="
date -u
echo "=== gcloud auth list (end) ==="
gcloud auth list
