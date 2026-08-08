#!/usr/bin/env bash
set -euo pipefail
echo "=== date -u ==="
date -u
echo "=== staging table state for this run_id ==="
bq query --use_legacy_sql=false --format=pretty \
"SELECT COUNT(*) AS row_count, MIN(transaction_date_raw) AS min_date, MAX(transaction_date_raw) AS max_date, MAX(_loaded_at) AS max_loaded_at
 FROM \`msklad-bi-prod.stg_msklad.fact_sales_staging\`
 WHERE run_id = 'verify_deploy_2026-08-08_document_owner_weekly'"
echo "=== staging table state, ANY run_id, most recent _loaded_at ==="
bq query --use_legacy_sql=false --format=pretty \
"SELECT run_id, COUNT(*) AS row_count, MAX(_loaded_at) AS max_loaded_at
 FROM \`msklad-bi-prod.stg_msklad.fact_sales_staging\`
 GROUP BY run_id ORDER BY max_loaded_at DESC LIMIT 5"
echo "=== GCS incremental path for this run_id ==="
gsutil ls -l "gs://msklad-raw-msklad-bi-prod/demand/incremental/run_verify_deploy_2026-08-08_document_owner_weekly.ndjson.gz" 2>&1 || echo "NOT FOUND"
echo "=== cf-facts logs for this run_id (last hour) ==="
gcloud logging read 'resource.type="cloud_run_revision" resource.labels.service_name="cf-facts" jsonPayload.run_id="verify_deploy_2026-08-08_document_owner_weekly"' \
  --project=msklad-bi-prod --freshness=1h --format=json --limit=50 > logging_read_weekly.json 2>&1
python3 -c "
import json
with open('logging_read_weekly.json') as f:
    entries = json.load(f)
print('log entries found:', len(entries))
for e in reversed(entries):
    ts = e.get('timestamp')
    sev = e.get('severity')
    payload = e.get('jsonPayload') or e.get('textPayload')
    print(ts, sev, payload)
"
