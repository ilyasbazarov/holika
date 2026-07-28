#!/bin/bash
set -euo pipefail

echo "=== ANCHOR START ==="
date -u
gcloud auth list --filter=status:ACTIVE --format='value(account)'
echo "=== ANCHOR START END ==="

echo
echo "### read-only describe живого transferConfig (sq_marts_expenses) ###"
bq show --transfer_config --format=prettyjson \
  "projects/420804682491/locations/asia-east1/transferConfigs/6a22a243-0000-20fd-a458-883d24f4cad4" \
  > live_config_before.json
cat live_config_before.json

echo
echo "### Полное имя ресурса (project number / location) ###"
python3 -c "
import json
c = json.load(open('live_config_before.json'))
print('name:', c['name'])
print('destinationDatasetId:', c.get('destinationDatasetId'))
print('params keys:', list(c.get('params', {}).keys()))
print('destination_table_name_template:', c.get('params', {}).get('destination_table_name_template'))
print('write_disposition:', c.get('params', {}).get('write_disposition'))
print('partitioning_field:', repr(c.get('params', {}).get('partitioning_field')))
print('query bytes (before):', len(c.get('params', {}).get('query', '').encode('utf-8')))
"

echo
echo "### Откатный текст SQL (снят ДО первого касания) — сверка размера с reference/sql/sq_marts_expenses.sql ###"
python3 -c "
import json
c = json.load(open('live_config_before.json'))
q = c['params']['query']
open('rollback_query_before_fx_policy.sql', 'w').write(q)
print('rollback file bytes:', len(q.encode('utf-8')))
"
wc -c reference/sql/sq_marts_expenses.sql rollback_query_before_fx_policy.sql
diff -q reference/sql/sq_marts_expenses.sql rollback_query_before_fx_policy.sql && echo "СОВПАДАЕТ побайтово со снапшотом в репо" || echo "!!! РАСХОДИТСЯ со снапшотом в репо — СТОП"

echo
echo "=== ANCHOR END ==="
date -u
gcloud auth list --filter=status:ACTIVE --format='value(account)'
echo "=== ANCHOR END END ==="
