#!/bin/bash
set -uo pipefail
cd "$(dirname "$0")/../.."

echo "=== date -u (start) ==="
date -u
echo "=== gcloud auth list (start) ==="
gcloud auth list

CONFIG_ID="6a1f9418-0000-276f-a1e4-d4f547ee7418"
OUT_DIR="reference/_scratch_MARTS-STAMP-WEIGHTFLOW_2026-08-18"
SQL_FILE="reference/sql/sq_marts_weight_flow_stamped_2026-08-13.sql"

echo "=== bq update --transfer_config ==="
bq update --transfer_config \
  --params="{\"query\": $(python3 -c "import json; print(json.dumps(open('${SQL_FILE}').read()))")}" \
  "projects/420804682491/locations/asia-east1/transferConfigs/${CONFIG_ID}" \
  > "${OUT_DIR}/update_result_2026-08-18.log" 2> "${OUT_DIR}/update_result_2026-08-18.err"
echo "rc=$?"
cat "${OUT_DIR}/update_result_2026-08-18.log"
cat "${OUT_DIR}/update_result_2026-08-18.err"

echo "=== date -u (end) ==="
date -u
echo "=== gcloud auth list (end) ==="
gcloud auth list
