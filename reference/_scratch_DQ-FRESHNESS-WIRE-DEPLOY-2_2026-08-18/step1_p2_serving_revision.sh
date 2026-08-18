#!/usr/bin/env bash
set -euo pipefail

echo "=== UTC anchor (start) ==="
date -u
echo "=== gcloud auth list (start) ==="
gcloud auth list

echo "=== П2: снятие обслуживающей ревизии cf-dq ==="
gcloud functions describe cf-dq --gen2 --region=asia-east1 --project=msklad-bi-prod \
  --format=json > "$(dirname "${BASH_SOURCE[0]}")/step1_describe_cf_dq.json"

echo "--- serviceConfig.revision / traffic ---"
python3 -c "
import json
d = json.load(open('$(dirname "${BASH_SOURCE[0]}")/step1_describe_cf_dq.json'))
print('revision:', d.get('serviceConfig', {}).get('revision'))
print('state:', d.get('state'))
print('sourceStorage:', d.get('buildConfig', {}).get('source', {}).get('storageSource'))
"

echo "--- gcloud run services describe (traffic split, percent) ---"
gcloud run services describe cf-dq --region=asia-east1 --project=msklad-bi-prod \
  --format="value(status.traffic)" > "$(dirname "${BASH_SOURCE[0]}")/step1_run_traffic.txt"
cat "$(dirname "${BASH_SOURCE[0]}")/step1_run_traffic.txt"

echo "=== UTC anchor (end) ==="
date -u
echo "=== gcloud auth list (end) ==="
gcloud auth list
