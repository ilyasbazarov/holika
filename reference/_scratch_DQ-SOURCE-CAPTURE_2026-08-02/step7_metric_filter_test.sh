#!/bin/bash
set -euo pipefail
SCRATCH="reference/_scratch_DQ-SOURCE-CAPTURE_2026-08-02"

echo "=== date -u (start) ==="
date -u
echo "=== gcloud auth list (start) ==="
gcloud auth list

echo "=== testing metric's EXACT filter over 90 days ==="
gcloud logging read 'resource.type="cloud_run_revision"
resource.labels.service_name="cf-dq"
jsonPayload.message=~"DQ.*FAILED|dq_gate.*fail|check failed"
severity>=ERROR' \
  --project=msklad-bi-prod --freshness=90d --format=json --limit=10 \
  > "$SCRATCH/step7_metric_filter_match.json" 2>"$SCRATCH/step7.err" || cat "$SCRATCH/step7.err"

python3 -c "
import json
try:
    d = json.load(open('$SCRATCH/step7_metric_filter_match.json'))
    print('MATCH COUNT (90d, up to 10 shown):', len(d))
except Exception as e:
    print('parse/empty:', e)
"
cat "$SCRATCH/step7_metric_filter_match.json"

echo "=== date -u (end) ==="
date -u
echo "=== gcloud auth list (end) ==="
gcloud auth list
