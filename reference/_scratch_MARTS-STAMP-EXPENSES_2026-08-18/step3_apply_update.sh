#!/bin/bash
set -uo pipefail
cd "$(dirname "$0")/../.."

echo "=== date -u (start) ==="
date -u
echo "=== gcloud auth list (start) ==="
gcloud auth list

CONFIG_ID="6a22a243-0000-20fd-a458-883d24f4cad4"
OUT_DIR="reference/_scratch_MARTS-STAMP-EXPENSES_2026-08-18"
SQL_FILE="reference/sql/sq_marts_expenses_stamped_2026-08-13.sql"

echo "=== bq update --transfer_config (полный params: query новый + три поля сохранены) ==="
python3 -c "
import json
query = open('${SQL_FILE}').read()
params = {
    'destination_table_name_template': 'expenses',
    'partitioning_field': '',
    'query': query,
    'write_disposition': 'WRITE_TRUNCATE',
}
print(json.dumps(params))
" > "${OUT_DIR}/update_params_payload_2026-08-18.json"

bq update --transfer_config \
  --params="$(cat "${OUT_DIR}/update_params_payload_2026-08-18.json")" \
  "projects/420804682491/locations/asia-east1/transferConfigs/${CONFIG_ID}" \
  > "${OUT_DIR}/update_result_2026-08-18.log" 2> "${OUT_DIR}/update_result_2026-08-18.err"
echo "rc=$?"
cat "${OUT_DIR}/update_result_2026-08-18.log"
cat "${OUT_DIR}/update_result_2026-08-18.err"

echo "=== date -u (end) ==="
date -u
echo "=== gcloud auth list (end) ==="
gcloud auth list
