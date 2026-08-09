#!/bin/bash
set -uo pipefail
echo "=== date -u (start) ==="
date -u
echo "=== gcloud auth list (start) ==="
gcloud auth list

echo "=== CURRENT metric filter, verbatim, over same 90d window, count ==="
gcloud logging read '
resource.type="cloud_run_revision"
resource.labels.service_name="cf-dq"
jsonPayload.message=~"DQ.*FAILED|dq_gate.*fail|check failed"
severity>=ERROR
timestamp>="2026-05-11T00:00:00Z"
timestamp<="2026-08-09T13:55:00Z"
' --project=msklad-bi-prod --format=json --limit=1000 > current_filter_90d.json 2>&1
echo "match_count=$(python3 -c "import json;print(len(json.load(open('current_filter_90d.json'))))" 2>/dev/null || echo PARSE_FAILED)"

echo "=== date -u (end) ==="
date -u
echo "=== gcloud auth list (end) ==="
gcloud auth list
