#!/usr/bin/env bash
set -euo pipefail
echo "=== date -u (start) ==="
date -u
echo "=== gcloud auth list (start) ==="
gcloud auth list
echo "=== bq show --schema core.fact_sales_profit ==="
bq show --format=prettyjson msklad-bi-prod:core.fact_sales_profit | python3 -c "
import json,sys
d = json.load(sys.stdin)
cols = [f['name'] for f in d['schema']['fields']]
print('columns:', len(cols))
for c in cols:
    print(' -', c)
print()
print('document_owner_employee_id present:', 'document_owner_employee_id' in cols)
"
echo "=== date -u (end) ==="
date -u
echo "=== gcloud auth list (end) ==="
gcloud auth list
