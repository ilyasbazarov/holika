#!/bin/bash
set -uo pipefail
cd "$(dirname "$0")/../.."

echo "=== date -u (start) ==="
date -u
echo "=== gcloud auth list (start) ==="
gcloud auth list

OUT_DIR="reference/_scratch_MARTS-STAMP-WEIGHTFLOW_2026-08-18"
RUN_NAME="projects/420804682491/locations/asia-east1/transferConfigs/6a1f9418-0000-276f-a1e4-d4f547ee7418/runs/6a842921-0000-2ca7-b29b-582429aeee7c"

STATE="PENDING"
for i in $(seq 1 30); do
  bq show --format=prettyjson --transfer_run "${RUN_NAME}" > "${OUT_DIR}/run_poll_${i}.json" 2> "${OUT_DIR}/run_poll_${i}.err"
  STATE=$(python3 -c "import json; print(json.load(open('${OUT_DIR}/run_poll_${i}.json'))['state'])" 2>/dev/null || echo "UNKNOWN")
  echo "poll ${i}: state=${STATE}"
  if [ "${STATE}" = "SUCCEEDED" ] || [ "${STATE}" = "FAILED" ] || [ "${STATE}" = "CANCELLED" ]; then
    cp "${OUT_DIR}/run_poll_${i}.json" "${OUT_DIR}/run_final_2026-08-18.json"
    break
  fi
  sleep 10
done

echo "=== финальное состояние: ${STATE} ==="

echo "=== date -u (end) ==="
date -u
echo "=== gcloud auth list (end) ==="
gcloud auth list
