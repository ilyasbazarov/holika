#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

echo "=== date -u (start) ==="
date -u
echo "=== gcloud auth list (start) ==="
gcloud auth list

RUN_TIME=$(date -u +%Y-%m-%dT%H:%M:%SZ)
echo "run_time: $RUN_TIME"

echo "=== bq mk --transfer_run ==="
bq mk --transfer_run --run_time="$RUN_TIME" \
  projects/420804682491/locations/asia-east1/transferConfigs/6a22a243-0000-20fd-a458-883d24f4cad4

echo "=== date -u (end) ==="
date -u
echo "=== gcloud auth list (end) ==="
gcloud auth list
