#!/bin/bash
set -uo pipefail
echo "=== date -u (start) ==="
date -u
echo "=== gcloud auth list (start) ==="
gcloud auth list

echo "=== proposed filter, over full 90-day window (2026-05-11..2026-08-09), count ==="
gcloud logging read '
resource.type="workflows.googleapis.com/Workflow"
resource.labels.workflow_id=~"^msklad-pipeline"
severity>=CRITICAL
textPayload=~"DQ Gate FAILED"
timestamp>="2026-05-11T00:00:00Z"
timestamp<="2026-08-09T13:55:00Z"
' --project=msklad-bi-prod --format=json --limit=1000 > proposed_filter_90d.json 2>&1
echo "match_count=$(python3 -c "import json;print(len(json.load(open('proposed_filter_90d.json'))))" 2>/dev/null || echo PARSE_FAILED)"

echo "=== proposed filter, narrow window around known event 2026-08-01T18:02:01Z ==="
gcloud logging read '
resource.type="workflows.googleapis.com/Workflow"
resource.labels.workflow_id=~"^msklad-pipeline"
severity>=CRITICAL
textPayload=~"DQ Gate FAILED"
timestamp>="2026-08-01T18:00:00Z"
timestamp<="2026-08-01T18:10:00Z"
' --project=msklad-bi-prod --format=json --limit=20

echo "=== date -u (end) ==="
date -u
echo "=== gcloud auth list (end) ==="
gcloud auth list
