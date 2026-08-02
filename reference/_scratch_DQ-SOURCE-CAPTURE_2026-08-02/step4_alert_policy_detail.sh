#!/bin/bash
set -euo pipefail
SCRATCH="reference/_scratch_DQ-SOURCE-CAPTURE_2026-08-02"

echo "=== date -u (start) ==="
date -u
echo "=== gcloud auth list (start) ==="
gcloud auth list

echo "=== msklad-dq-gate-failed policy detail ==="
POLICY_NAME=$(python3 -c "
import json
d = json.load(open('$SCRATCH/step3_monitoring_policies.json'))
for p in d:
    if p.get('displayName') == 'msklad-dq-gate-failed':
        print(p.get('name'))
")
echo "POLICY_NAME=$POLICY_NAME"
gcloud alpha monitoring policies describe "$POLICY_NAME" --project=msklad-bi-prod --format=json \
  > "$SCRATCH/step4_dq_gate_failed_policy.json" 2>"$SCRATCH/step4_policy.err" || cat "$SCRATCH/step4_policy.err"
cat "$SCRATCH/step4_dq_gate_failed_policy.json"

echo "=== notification channels detail ==="
for CH in projects/msklad-bi-prod/notificationChannels/876055528317282377 projects/msklad-bi-prod/notificationChannels/13959469767726741244; do
  echo "--- $CH ---"
  gcloud alpha monitoring channels describe "$CH" --project=msklad-bi-prod --format=json 2>>"$SCRATCH/step4_channels.err" | tee -a "$SCRATCH/step4_channels.json"
done

echo "=== date -u (end) ==="
date -u
echo "=== gcloud auth list (end) ==="
gcloud auth list
