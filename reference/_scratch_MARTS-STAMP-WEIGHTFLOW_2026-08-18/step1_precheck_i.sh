#!/bin/bash
set -uo pipefail
cd "$(dirname "$0")/../.."

echo "=== date -u (start) ==="
date -u
echo "=== gcloud auth list (start) ==="
gcloud auth list

CONFIG_ID="6a1f9418-0000-276f-a1e4-d4f547ee7418"
OUT_DIR="reference/_scratch_MARTS-STAMP-WEIGHTFLOW_2026-08-18"

echo "=== bq show --transfer_config (JSON) ==="
bq show --transfer_config --format=prettyjson \
  "projects/420804682491/locations/asia-east1/transferConfigs/${CONFIG_ID}" \
  > "${OUT_DIR}/live_transfer_config_2026-08-18.json" 2> "${OUT_DIR}/live_transfer_config_2026-08-18.err"
echo "rc=$?"

python3 -c "
import json
with open('${OUT_DIR}/live_transfer_config_2026-08-18.json') as f:
    d = json.load(f)
q = d['params']['query']
with open('${OUT_DIR}/live_query_extracted_2026-08-18.sql', 'w') as f:
    f.write(q)
"

echo "=== длины файлов (байт) ==="
wc -c "${OUT_DIR}/live_query_extracted_2026-08-18.sql" reference/sql/sq_marts_weight_flow.sql

echo "=== diff (живой снимок vs снимок репо) ==="
diff "${OUT_DIR}/live_query_extracted_2026-08-18.sql" reference/sql/sq_marts_weight_flow.sql
echo "diff rc=$?"

echo "=== date -u (end) ==="
date -u
echo "=== gcloud auth list (end) ==="
gcloud auth list
