#!/bin/bash
set -uo pipefail
cd "$(dirname "$0")/../.."

echo "=== date -u (start) ==="
date -u
echo "=== gcloud auth list (start) ==="
gcloud auth list

CONFIG_ID="6a23f3ea-0000-2952-853d-582429be7ecc"
OUT_DIR="reference/_scratch_MARTS-STAMP-CUSTINVAR_2026-08-18"
SQL_FILE="reference/sql/sq_marts_customer_invoices_ar_stamped_2026-08-13.sql"

echo "=== bq update --transfer_config (полный params: query + три восстановленных поля) ==="
python3 -c "
import json
query = open('${SQL_FILE}').read()
params = {
    'destination_table_name_template': 'customer_invoices_ar',
    'partitioning_field': '',
    'query': query,
    'write_disposition': 'WRITE_TRUNCATE',
}
print(json.dumps(params))
" > "${OUT_DIR}/fix_params_payload_2026-08-18.json"

bq update --transfer_config \
  --params="$(cat "${OUT_DIR}/fix_params_payload_2026-08-18.json")" \
  "projects/420804682491/locations/asia-east1/transferConfigs/${CONFIG_ID}" \
  > "${OUT_DIR}/fix_update_result_2026-08-18.log" 2> "${OUT_DIR}/fix_update_result_2026-08-18.err"
echo "rc=$?"
cat "${OUT_DIR}/fix_update_result_2026-08-18.log"
cat "${OUT_DIR}/fix_update_result_2026-08-18.err"

echo "=== date -u (end) ==="
date -u
echo "=== gcloud auth list (end) ==="
gcloud auth list
