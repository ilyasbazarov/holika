#!/usr/bin/env bash
set -euo pipefail
echo "=== date -u (start) ==="
date -u
echo "=== gcloud auth list (start) ==="
gcloud auth list
echo "=== ALTER TABLE ==="
bq query --use_legacy_sql=false \
"ALTER TABLE \`msklad-bi-prod.core.fact_sales_profit\` ADD COLUMN document_owner_employee_id STRING"
echo "=== bq show --schema core.fact_sales_profit (after) ==="
bq show --format=prettyjson msklad-bi-prod:core.fact_sales_profit | python3 -c "
import json,sys
d = json.load(sys.stdin)
cols = {f['name']: f['type'] for f in d['schema']['fields']}
print('columns:', len(cols))
for name, typ in cols.items():
    print(' -', name, ':', typ)
print()
print('document_owner_employee_id:', cols.get('document_owner_employee_id', 'ABSENT'))
"
echo "=== date -u (end) ==="
date -u
echo "=== gcloud auth list (end) ==="
gcloud auth list
