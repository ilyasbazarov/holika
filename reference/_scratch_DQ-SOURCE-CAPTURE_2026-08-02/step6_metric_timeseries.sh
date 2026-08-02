#!/bin/bash
set -euo pipefail
SCRATCH="reference/_scratch_DQ-SOURCE-CAPTURE_2026-08-02"

echo "=== date -u (start) ==="
date -u
echo "=== gcloud auth list (start) ==="
gcloud auth list

echo "=== time series for msklad_dq_gate_failed, last 90 days ==="
END=$(date -u +%Y-%m-%dT%H:%M:%SZ)
START=$(date -u -v-90d +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d '90 days ago' +%Y-%m-%dT%H:%M:%SZ)
echo "window: $START .. $END"
gcloud monitoring time-series list \
  --project=msklad-bi-prod \
  --filter='metric.type="logging.googleapis.com/user/msklad_dq_gate_failed"' \
  --interval-start-time="$START" \
  --interval-end-time="$END" \
  --format=json \
  > "$SCRATCH/step6_timeseries.json" 2>"$SCRATCH/step6_timeseries.err" || cat "$SCRATCH/step6_timeseries.err"
cat "$SCRATCH/step6_timeseries.json"
echo "=== point count ==="
python3 -c "
import json
try:
    d = json.load(open('$SCRATCH/step6_timeseries.json'))
    print('series count:', len(d))
    for s in d:
        print('points:', len(s.get('points',[])))
except Exception as e:
    print('parse error / empty:', e)
"

echo "=== does cf-dq itself emit jsonPayload logs at all? sample raw log entry structure ==="
gcloud logging read 'resource.type="cloud_run_revision" AND resource.labels.service_name="cf-dq"' \
  --project=msklad-bi-prod --freshness=7d --format=json --limit=3 \
  > "$SCRATCH/step6_cfdq_raw_sample.json" 2>"$SCRATCH/step6_sample.err" || cat "$SCRATCH/step6_sample.err"
python3 -c "
import json
try:
    d = json.load(open('$SCRATCH/step6_cfdq_raw_sample.json'))
    print('entries:', len(d))
    for e in d[:3]:
        print('---')
        print('resource.type:', e.get('resource',{}).get('type'))
        print('resource.labels:', e.get('resource',{}).get('labels'))
        print('severity:', e.get('severity'))
        print('has textPayload:', 'textPayload' in e)
        print('has jsonPayload:', 'jsonPayload' in e)
        if 'jsonPayload' in e:
            print('jsonPayload keys:', list(e['jsonPayload'].keys()))
except Exception as ex:
    print('parse error:', ex)
"

echo "=== date -u (end) ==="
date -u
echo "=== gcloud auth list (end) ==="
gcloud auth list
