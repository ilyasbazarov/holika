#!/bin/bash
set -euo pipefail
echo "=== date -u (start) ==="
date -u
echo "=== gcloud auth list (start) ==="
gcloud auth list
echo "=== gcloud functions describe cf-facts ==="
gcloud functions describe cf-facts --gen2 --region=asia-east1 --project=msklad-bi-prod --format=json > /tmp/cf-facts-describe-check.json 2>&1 || cat /tmp/cf-facts-describe-check.json
python3 -c "
import json
d = json.load(open('/tmp/cf-facts-describe-check.json'))
print('revision:', d['serviceConfig']['revision'])
print('generation:', d['buildConfig']['source']['storageSource']['generation'])
print('updateTime:', d.get('updateTime'))
"
echo "=== gcloud auth list (end) ==="
gcloud auth list
echo "=== date -u (end) ==="
date -u
