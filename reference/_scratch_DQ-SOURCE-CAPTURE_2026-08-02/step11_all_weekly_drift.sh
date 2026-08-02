#!/bin/bash
set -euo pipefail
SCRATCH="reference/_scratch_DQ-SOURCE-CAPTURE_2026-08-02"

echo "=== date -u (start) ==="
date -u
echo "=== gcloud auth list (start) ==="
gcloud auth list

echo "=== all [WEEKLY] DQ Gate log lines, 90d ==="
gcloud logging read 'resource.type="workflows.googleapis.com/Workflow"
resource.labels.workflow_id="msklad-pipeline-weekly"
textPayload:"DQ Gate"' \
  --project=msklad-bi-prod --freshness=90d --format="value(timestamp,textPayload)" --order=asc \
  > "$SCRATCH/step11_weekly_dq_all.log" 2>"$SCRATCH/step11.err" || cat "$SCRATCH/step11.err"

wc -l "$SCRATCH/step11_weekly_dq_all.log"
cat "$SCRATCH/step11_weekly_dq_all.log"

echo "=== date -u (end) ==="
date -u
echo "=== gcloud auth list (end) ==="
gcloud auth list
