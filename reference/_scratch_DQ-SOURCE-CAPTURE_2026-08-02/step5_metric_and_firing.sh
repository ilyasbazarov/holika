#!/bin/bash
set -euo pipefail
SCRATCH="reference/_scratch_DQ-SOURCE-CAPTURE_2026-08-02"

echo "=== date -u (start) ==="
date -u
echo "=== gcloud auth list (start) ==="
gcloud auth list

echo "=== log-based metric msklad_dq_gate_failed ==="
gcloud logging metrics describe msklad_dq_gate_failed --project=msklad-bi-prod --format=json \
  > "$SCRATCH/step5_metric_describe.json" 2>"$SCRATCH/step5_metric.err" || cat "$SCRATCH/step5_metric.err"
cat "$SCRATCH/step5_metric_describe.json"

echo "=== recent CRITICAL DQ Gate FAILED log entries (last 10 days) ==="
gcloud logging read 'severity=CRITICAL AND textPayload:"DQ Gate FAILED"' \
  --project=msklad-bi-prod --freshness=10d --format="value(timestamp,textPayload)" --limit=50 \
  > "$SCRATCH/step5_critical_entries.log" 2>"$SCRATCH/step5_critical.err" || cat "$SCRATCH/step5_critical.err"
wc -l "$SCRATCH/step5_critical_entries.log"
cat "$SCRATCH/step5_critical_entries.log"

echo "=== date -u (end) ==="
date -u
echo "=== gcloud auth list (end) ==="
gcloud auth list
