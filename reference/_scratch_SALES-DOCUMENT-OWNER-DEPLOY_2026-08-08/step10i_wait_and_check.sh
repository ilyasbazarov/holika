#!/usr/bin/env bash
set -euo pipefail
echo "=== date -u (start) ==="
date -u
for i in $(seq 1 12); do
  sleep 20
  gcloud logging read 'resource.type="cloud_run_revision" resource.labels.service_name="cf-facts" resource.labels.revision_name="cf-facts-00010-mog" httpRequest.status>=0 timestamp>="2026-08-08T14:14:00Z"' \
    --project=msklad-bi-prod --format=json --limit=10 > /tmp/httpreq_poll.json 2>&1
  n=$(python3 -c "import json; print(len(json.load(open('/tmp/httpreq_poll.json'))))" 2>/dev/null || echo 0)
  echo "poll $i: entries=$n"
  if [ "$n" -gt 0 ]; then
    break
  fi
done
echo "=== final httpRequest entries ==="
cat /tmp/httpreq_poll.json
echo "=== date -u (end) ==="
date -u
