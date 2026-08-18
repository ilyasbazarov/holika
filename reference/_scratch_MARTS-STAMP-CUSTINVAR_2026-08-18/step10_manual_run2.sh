#!/bin/bash
set -uo pipefail
cd "$(dirname "$0")/../.."

echo "=== date -u (start) ==="
date -u
echo "=== gcloud auth list (start) ==="
gcloud auth list

CONFIG_ID="6a23f3ea-0000-2952-853d-582429be7ecc"
OUT_DIR="reference/_scratch_MARTS-STAMP-CUSTINVAR_2026-08-18"

echo "=== bq mk --transfer_run (второй ручной прогон, после исправления) ==="
NOW_TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
bq mk --transfer_run \
  --run_time="${NOW_TS}" \
  "projects/420804682491/locations/asia-east1/transferConfigs/${CONFIG_ID}" \
  > "${OUT_DIR}/manual_run2_trigger_2026-08-18.log" 2> "${OUT_DIR}/manual_run2_trigger_2026-08-18.err"
echo "rc=$?"
cat "${OUT_DIR}/manual_run2_trigger_2026-08-18.log"
cat "${OUT_DIR}/manual_run2_trigger_2026-08-18.err"

echo "=== date -u (end) ==="
date -u
echo "=== gcloud auth list (end) ==="
gcloud auth list
