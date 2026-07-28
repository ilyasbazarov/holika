#!/bin/bash
set -euo pipefail

echo "=== ANCHOR START ==="
date -u
gcloud auth list --filter=status:ACTIVE --format='value(account)'
echo "=== ANCHOR START END ==="

echo
echo "### Read-back после подмены (read-only) ###"
bq show --transfer_config --format=prettyjson \
  "projects/420804682491/locations/asia-east1/transferConfigs/6a22a243-0000-20fd-a458-883d24f4cad4" \
  > live_config_after.json

python3 << 'PYEOF'
import json
before = json.load(open('live_config_before.json'))
after = json.load(open('live_config_after.json'))
new_sql = open('sq_marts_expenses_new.sql').read()

checks = []
checks.append(('query текст совпадает с sq_marts_expenses_new.sql', after['params']['query'] == new_sql))
checks.append(('destination_table_name_template не изменился', after['params']['destination_table_name_template'] == before['params']['destination_table_name_template'] == 'expenses'))
checks.append(('write_disposition не изменился', after['params']['write_disposition'] == before['params']['write_disposition'] == 'WRITE_TRUNCATE'))
checks.append(('partitioning_field не изменился', after['params']['partitioning_field'] == before['params']['partitioning_field'] == ''))
checks.append(('nextRunTime не изменился', after['nextRunTime'] == before['nextRunTime']))
checks.append(('scheduleOptionsV2 не изменился', after['scheduleOptionsV2'] == before['scheduleOptionsV2']))
checks.append(('state не изменился (SUCCEEDED)', after['state'] == before['state']))
checks.append(('ownerInfo не изменился', after['ownerInfo'] == before['ownerInfo']))
checks.append(('destinationDatasetId не изменился', after['destinationDatasetId'] == before['destinationDatasetId']))

ok_all = True
for name, ok in checks:
    print(('OK   ' if ok else 'FAIL ') + name)
    ok_all = ok_all and ok

print()
print('query bytes after:', len(after['params']['query'].encode('utf-8')))
print('ВСЕ ПРОВЕРКИ:', 'OK' if ok_all else 'FAIL — СТОП')
PYEOF

echo
echo "=== ANCHOR END ==="
date -u
gcloud auth list --filter=status:ACTIVE --format='value(account)'
echo "=== ANCHOR END END ==="
