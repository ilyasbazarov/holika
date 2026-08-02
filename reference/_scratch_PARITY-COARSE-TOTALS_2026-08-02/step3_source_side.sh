#!/usr/bin/env bash
set -euo pipefail

echo "=== date -u (start) ==="
date -u

echo "=== gcloud auth list (start) ==="
gcloud auth list

export MSKLAD_TOKEN
MSKLAD_TOKEN="$(gcloud secrets versions access latest --secret=msklad-token --project=msklad-bi-prod)"
echo "MSKLAD_TOKEN длина строки: ${#MSKLAD_TOKEN}"

python3 reference/_scratch_PARITY-COARSE-TOTALS_2026-08-02/step3_source_side.py

unset MSKLAD_TOKEN

echo "=== date -u (end) ==="
date -u

echo "=== gcloud auth list (end) ==="
gcloud auth list
