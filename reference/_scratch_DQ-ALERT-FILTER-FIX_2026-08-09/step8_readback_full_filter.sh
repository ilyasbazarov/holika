#!/bin/bash
set -uo pipefail
echo "=== date -u (start) ==="
date -u
echo "=== gcloud auth list (start) ==="
gcloud auth list

echo "=== full describe of updated metric ==="
gcloud logging metrics describe msklad_dq_gate_failed --project=msklad-bi-prod --format=yaml

echo "=== date -u (end) ==="
date -u
echo "=== gcloud auth list (end) ==="
gcloud auth list
