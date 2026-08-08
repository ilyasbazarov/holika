#!/usr/bin/env bash
set -euo pipefail
echo "=== date -u ==="
date -u
echo "=== full logs 13:14-13:30 UTC, cf-facts-00010-mog ==="
gcloud logging read 'resource.type="cloud_run_revision" resource.labels.service_name="cf-facts" resource.labels.revision_name="cf-facts-00010-mog" timestamp>="2026-08-08T13:14:00Z" timestamp<="2026-08-08T13:30:00Z"' \
  --project=msklad-bi-prod --format=json --limit=200 > logging_window1.json 2>&1
python3 -c "
import json
with open('logging_window1.json') as f:
    entries = json.load(f)
print('entries:', len(entries))
for e in reversed(entries):
    ts = e.get('timestamp')
    sev = e.get('severity')
    payload = e.get('jsonPayload') or e.get('textPayload')
    print('---', ts, sev)
    print(payload)
"
