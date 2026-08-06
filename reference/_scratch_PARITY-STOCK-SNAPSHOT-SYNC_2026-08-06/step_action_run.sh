#!/usr/bin/env bash
set -uo pipefail
echo "=== date -u (start) ==="; date -u
echo "=== gcloud auth list (start) ==="; gcloud auth list
echo "=== gcloud scheduler jobs run cf-inventory-trigger ==="
gcloud scheduler jobs run cf-inventory-trigger --location=asia-east1
echo "RC(scheduler run)=$?"
echo "=== date -u (end) ==="; date -u
echo "=== gcloud auth list (end) ==="; gcloud auth list
