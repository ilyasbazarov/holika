#!/bin/bash
set -euo pipefail
SCRATCH="reference/_scratch_DQ-SOURCE-CAPTURE_2026-08-02"

echo "=== date -u (start) ==="
date -u
echo "=== gcloud auth list (start) ==="
gcloud auth list

for NAME in msklad-workflow-execution-failed msklad-cf-error msklad-workflow-silent-skip; do
  echo "=== $NAME ==="
  POLICY_NAME=$(python3 -c "
import json
d = json.load(open('$SCRATCH/step3_monitoring_policies.json'))
for p in d:
    if p.get('displayName') == '$NAME':
        print(p.get('name'))
")
  gcloud alpha monitoring policies describe "$POLICY_NAME" --project=msklad-bi-prod --format=json 2>&1
  echo
done

echo "=== date -u (end) ==="
date -u
echo "=== gcloud auth list (end) ==="
gcloud auth list
