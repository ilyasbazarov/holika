#!/bin/bash
set -uo pipefail
cd "$(dirname "$0")/../.."

echo "=== date -u (start) ==="
date -u
echo "=== gcloud auth list (start) ==="
gcloud auth list

CONFIG_ID="6a22a243-0000-20fd-a458-883d24f4cad4"
OUT_DIR="reference/_scratch_MARTS-STAMP-EXPENSES_2026-08-18"

echo "=== bq show --transfer_config (JSON, params ЦЕЛИКОМ) ==="
bq show --transfer_config --format=prettyjson \
  "projects/420804682491/locations/asia-east1/transferConfigs/${CONFIG_ID}" \
  > "${OUT_DIR}/live_transfer_config_2026-08-18.json" 2> "${OUT_DIR}/live_transfer_config_2026-08-18.err"
echo "rc=$?"

echo "=== состав live params (ВСЕ поля, урок MARTS-STAMP-CUSTINVAR) ==="
python3 -c "
import json
d = json.load(open('${OUT_DIR}/live_transfer_config_2026-08-18.json'))
p = d['params']
print('ключи params:', sorted(p.keys()))
for k, v in p.items():
    if k != 'query':
        print(f'{k} = {v!r}')
with open('${OUT_DIR}/live_query_extracted_2026-08-18.sql', 'w') as f:
    f.write(p['query'])
with open('${OUT_DIR}/live_params_full_2026-08-18.json', 'w') as f:
    json.dump(p, f, ensure_ascii=False, indent=2)
"

echo "=== длины файлов (байт) ==="
wc -c "${OUT_DIR}/live_query_extracted_2026-08-18.sql" reference/sql/sq_marts_expenses.sql

echo "=== diff (живой снимок vs снимок репо) ==="
diff "${OUT_DIR}/live_query_extracted_2026-08-18.sql" reference/sql/sq_marts_expenses.sql
echo "diff rc=$?"

echo "=== date -u (end) ==="
date -u
echo "=== gcloud auth list (end) ==="
gcloud auth list
