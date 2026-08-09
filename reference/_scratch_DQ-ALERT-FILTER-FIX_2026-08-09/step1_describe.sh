#!/bin/bash
set -euo pipefail
echo "=== date -u (start) ==="
date -u
echo "=== gcloud auth list (start) ==="
gcloud auth list

echo "=== log-based metric: msklad-dq-gate-failed ==="
gcloud logging metrics describe msklad-dq-gate-failed --project=msklad-bi-prod --format=yaml

echo "=== alert policies list (enabled) ==="
gcloud alpha monitoring policies list --project=msklad-bi-prod --format=yaml

echo "=== date -u (end) ==="
date -u
echo "=== gcloud auth list (end) ==="
gcloud auth list
