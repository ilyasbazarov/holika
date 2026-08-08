#!/usr/bin/env bash
set -euo pipefail
echo "=== date -u ==="
date -u
echo "=== httpRequest logs cf-facts-00010-mog, 13:14-13:40 ==="
gcloud logging read 'resource.type="cloud_run_revision" resource.labels.service_name="cf-facts" resource.labels.revision_name="cf-facts-00010-mog" httpRequest.status>=0 timestamp>="2026-08-08T13:14:00Z" timestamp<="2026-08-08T13:40:00Z"' \
  --project=msklad-bi-prod --format=json --limit=50 > logging_httpreq.json 2>&1
python3 -c "
import json
with open('logging_httpreq.json') as f:
    entries = json.load(f)
print('entries:', len(entries))
for e in reversed(entries):
    ts = e.get('timestamp')
    hr = e.get('httpRequest', {})
    print(ts, 'status=', hr.get('status'), 'latency=', hr.get('latency'), 'requestUrl=', hr.get('requestUrl'))
"
