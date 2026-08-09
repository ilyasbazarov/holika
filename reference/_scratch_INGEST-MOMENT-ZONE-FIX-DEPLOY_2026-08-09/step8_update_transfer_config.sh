#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

echo "=== date -u (start) ==="
date -u
echo "=== gcloud auth list (start) ==="
gcloud auth list

python3 -c "
import json
new_query = open('../../reference/sql/sq_marts_expenses.sql').read()
params = {
    'destination_table_name_template': 'expenses',
    'partitioning_field': '',
    'query': new_query,
    'write_disposition': 'WRITE_TRUNCATE',
}
open('new_params.json','w').write(json.dumps(params))
"

echo "=== bq update --transfer_config ==="
bq update --transfer_config \
  --params="$(cat new_params.json)" \
  projects/420804682491/locations/asia-east1/transferConfigs/6a22a243-0000-20fd-a458-883d24f4cad4

echo "=== date -u (end) ==="
date -u
echo "=== gcloud auth list (end) ==="
gcloud auth list
