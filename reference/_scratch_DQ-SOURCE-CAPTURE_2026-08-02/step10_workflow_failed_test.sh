#!/bin/bash
set -euo pipefail
SCRATCH="reference/_scratch_DQ-SOURCE-CAPTURE_2026-08-02"

echo "=== date -u (start) ==="
date -u
echo "=== gcloud auth list (start) ==="
gcloud auth list

echo "=== testing msklad_workflow_execution_failed EXACT filter, 30d ==="
gcloud logging read 'resource.type="workflows.googleapis.com/Workflow"
resource.labels.workflow_id=~"^msklad-pipeline"
jsonPayload.state=~"FAILED|CANCELLED"' \
  --project=msklad-bi-prod --freshness=30d --format=json --limit=20 \
  > "$SCRATCH/step10_match.json" 2>"$SCRATCH/step10.err" || cat "$SCRATCH/step10.err"

python3 -c "
import json
try:
    d = json.load(open('$SCRATCH/step10_match.json'))
    print('MATCH COUNT (30d, up to 20 shown):', len(d))
    for e in d[:20]:
        print(e.get('timestamp'), e.get('resource',{}).get('labels',{}).get('workflow_id'), e.get('jsonPayload',{}).get('state'))
except Exception as e:
    print('parse/empty:', e)
"

echo "=== date -u (end) ==="
date -u
echo "=== gcloud auth list (end) ==="
gcloud auth list
