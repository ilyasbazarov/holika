#!/bin/bash
set -euo pipefail
SCRATCH="reference/_scratch_DQ-SOURCE-CAPTURE_2026-08-02"

echo "=== date -u (start) ==="
date -u
echo "=== gcloud auth list (start) ==="
gcloud auth list

echo "=== gcloud workflows describe msklad-pipeline-hourly ==="
gcloud workflows describe msklad-pipeline-hourly --location=asia-east1 --project=msklad-bi-prod --format=json \
  > "$SCRATCH/step2_hourly_workflow.json" 2>"$SCRATCH/step2_hourly.err" || {
    echo "describe FAILED"; cat "$SCRATCH/step2_hourly.err"
  }

echo "=== extract sourceContents (decode) ==="
python3 -c "
import json
d = json.load(open('$SCRATCH/step2_hourly_workflow.json'))
src = d.get('sourceContents','')
open('$SCRATCH/step2_hourly_workflow.yaml','w').write(src)
print(len(src), 'bytes written')
" || echo "python parse FAILED"

echo "=== grep cf-alert / raise_dq_failed in workflow source ==="
grep -n "cf-alert\|raise_dq_failed\|check_dq\|Telegram" "$SCRATCH/step2_hourly_workflow.yaml" || echo "NO MATCH"

echo "=== also weekly workflow, if it exists ==="
gcloud workflows describe msklad-pipeline-weekly --location=asia-east1 --project=msklad-bi-prod --format=json \
  > "$SCRATCH/step2_weekly_workflow.json" 2>"$SCRATCH/step2_weekly.err" || {
    echo "describe FAILED"; cat "$SCRATCH/step2_weekly.err"
  }
python3 -c "
import json
d = json.load(open('$SCRATCH/step2_weekly_workflow.json'))
src = d.get('sourceContents','')
open('$SCRATCH/step2_weekly_workflow.yaml','w').write(src)
print(len(src), 'bytes written')
" || echo "python parse FAILED (weekly)"
grep -n "cf-alert\|raise_dq_failed\|check_dq\|Telegram" "$SCRATCH/step2_weekly_workflow.yaml" || echo "NO MATCH (weekly)"

echo "=== date -u (end) ==="
date -u
echo "=== gcloud auth list (end) ==="
gcloud auth list
