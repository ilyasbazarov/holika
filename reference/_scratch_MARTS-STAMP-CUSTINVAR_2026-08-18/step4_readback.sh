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

echo "=== bq show --transfer_config (после правки) ==="
bq show --transfer_config --format=prettyjson \
  "projects/420804682491/locations/asia-east1/transferConfigs/${CONFIG_ID}" \
  > "${OUT_DIR}/postupdate_config_2026-08-18.json" 2> "${OUT_DIR}/postupdate_config_2026-08-18.err"
echo "rc=$?"

python3 -c "
import json
with open('${OUT_DIR}/postupdate_config_2026-08-18.json') as f:
    d = json.load(f)
q = d['params']['query']
with open('${OUT_DIR}/postupdate_query_extracted_2026-08-18.sql', 'w') as f:
    f.write(q)
"

echo "=== длины (байт) ==="
wc -c "${OUT_DIR}/postupdate_query_extracted_2026-08-18.sql" "${SQL_FILE}"

echo "=== diff (read-back vs подготовленный файл) ==="
diff "${OUT_DIR}/postupdate_query_extracted_2026-08-18.sql" "${SQL_FILE}"
echo "diff rc=$?"

echo "=== sha256 сравнение ==="
shasum -a 256 "${OUT_DIR}/postupdate_query_extracted_2026-08-18.sql" "${SQL_FILE}"

echo "=== date -u (end) ==="
date -u
echo "=== gcloud auth list (end) ==="
gcloud auth list
