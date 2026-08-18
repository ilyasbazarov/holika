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

echo "=== bq show --transfer_config (после исправления) ==="
bq show --transfer_config --format=prettyjson \
  "projects/420804682491/locations/asia-east1/transferConfigs/${CONFIG_ID}" \
  > "${OUT_DIR}/fixed_config_2026-08-18.json" 2> "${OUT_DIR}/fixed_config_2026-08-18.err"
echo "rc=$?"

python3 -c "
import json
d = json.load(open('${OUT_DIR}/fixed_config_2026-08-18.json'))
p = d['params']
print('destination_table_name_template:', repr(p.get('destination_table_name_template')))
print('partitioning_field:', repr(p.get('partitioning_field')))
print('write_disposition:', repr(p.get('write_disposition')))
with open('${OUT_DIR}/fixed_query_extracted_2026-08-18.sql', 'w') as f:
    f.write(p['query'])
"

echo "=== diff (query read-back vs подготовленный файл) ==="
diff "${OUT_DIR}/fixed_query_extracted_2026-08-18.sql" "${SQL_FILE}"
echo "diff rc=$?"
shasum -a 256 "${OUT_DIR}/fixed_query_extracted_2026-08-18.sql" "${SQL_FILE}"

echo "=== date -u (end) ==="
date -u
echo "=== gcloud auth list (end) ==="
gcloud auth list
