#!/usr/bin/env bash
set -euo pipefail
echo "=== date -u ==="
date -u
echo "=== ALL cf-facts logs, last 2 hours, no run_id filter, severity >= DEFAULT ==="
gcloud logging read 'resource.type="cloud_run_revision" resource.labels.service_name="cf-facts"' \
  --project=msklad-bi-prod --freshness=2h --format=json --limit=200 > logging_read_all.json 2>&1
python3 -c "
import json
with open('logging_read_all.json') as f:
    entries = json.load(f)
print('total log entries (last 2h):', len(entries))
for e in reversed(entries):
    ts = e.get('timestamp')
    sev = e.get('severity')
    labels = e.get('labels', {})
    rev = e.get('resource', {}).get('labels', {}).get('revision_name')
    payload = e.get('jsonPayload') or e.get('textPayload')
    if isinstance(payload, dict):
        run_id = payload.get('run_id') or payload.get('message', '')[:120]
    else:
        run_id = str(payload)[:120] if payload else ''
    print(ts, sev, rev, '|', run_id)
"
