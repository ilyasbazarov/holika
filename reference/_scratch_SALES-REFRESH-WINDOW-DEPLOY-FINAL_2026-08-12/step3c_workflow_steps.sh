#!/usr/bin/env bash
set -euo pipefail

echo "=== UTC anchor (start) ==="
date -u
echo "=== gcloud auth (start) ==="
gcloud auth list

echo "=== workflow_hourly.yaml step order (from snapshot, for reference) ==="
grep -n "^\s*- \|call:\|step_" /Users/ilyasbazarov/Desktop/msklad_project/holika/worktrees/SALES-REFRESH-WINDOW-DEPLOY-FINAL/reference/code/cf-facts/workflow_hourly.yaml | head -60

echo "=== Cloud Logging: all log entries for the 16:00 workflow execution ==="
gcloud logging read \
  'resource.type="workflows.googleapis.com/Workflow" labels."workflows.googleapis.com/execution_id"="58620e72-5792-40ed-aabf-9510a0c35622"' \
  --project=msklad-bi-prod \
  --freshness=2h \
  --format="value(timestamp,severity,jsonPayload.state,jsonPayload.stackTrace.elements)" \
  --order=asc > wf_exec_16z_steps.txt
cat wf_exec_16z_steps.txt

echo "=== UTC anchor (end) ==="
date -u
echo "=== gcloud auth (end) ==="
gcloud auth list
