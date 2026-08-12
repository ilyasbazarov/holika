#!/usr/bin/env bash
set -euo pipefail
echo "=== date -u (start) ==="
date -u
echo "=== gcloud auth list (start) ==="
gcloud auth list
echo "=== update-traffic to cf-facts-00014-doh=100 ==="
gcloud run services update-traffic cf-facts \
  --region=asia-east1 --project=msklad-bi-prod \
  --to-revisions=cf-facts-00014-doh=100
echo "=== traffic after ==="
gcloud run services describe cf-facts --region=asia-east1 --project=msklad-bi-prod --format=json | python3 -c "
import json,sys
d=json.load(sys.stdin)
print('status.traffic:', d.get('status',{}).get('traffic'))
"
echo "=== gcloud auth list (end) ==="
gcloud auth list
echo "=== date -u (end) ==="
date -u
