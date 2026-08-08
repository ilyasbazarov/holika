#!/usr/bin/env bash
set -euo pipefail
echo "=== date -u ==="
date -u
echo "=== httpRequest logs cf-facts-00010-mog, 14:14-14:26 ==="
gcloud logging read 'resource.type="cloud_run_revision" resource.labels.service_name="cf-facts" resource.labels.revision_name="cf-facts-00010-mog" httpRequest.status>=0 timestamp>="2026-08-08T14:14:00Z" timestamp<="2026-08-08T14:26:00Z"' \
  --project=msklad-bi-prod --format=json --limit=50 > logging_httpreq2.json 2>&1
python3 -c "
import json
with open('logging_httpreq2.json') as f:
    entries = json.load(f)
print('entries:', len(entries))
for e in reversed(entries):
    ts = e.get('timestamp')
    hr = e.get('httpRequest', {})
    print(ts, 'status=', hr.get('status'), 'latency=', hr.get('latency'))
"
echo "=== staging table state for retry2 run_id ==="
bq query --use_legacy_sql=false --format=pretty \
"SELECT COUNT(*) AS row_count, MIN(transaction_date_raw) AS min_date, MAX(transaction_date_raw) AS max_date, MAX(_loaded_at) AS max_loaded_at
 FROM \`msklad-bi-prod.stg_msklad.fact_sales_staging\`
 WHERE run_id = 'verify_deploy_2026-08-08_document_owner_weekly_retry2'"
