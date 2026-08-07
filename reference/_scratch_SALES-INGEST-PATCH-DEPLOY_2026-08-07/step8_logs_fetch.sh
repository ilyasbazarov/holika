#!/usr/bin/env bash
set -euo pipefail

echo "=== UTC anchor (start) ==="
date -u
echo "=== caller identity (start) ==="
gcloud auth list

echo "=== cloud logging: cf-facts textPayload mentioning run_id ==="
gcloud logging read '
resource.type="cloud_run_revision"
resource.labels.service_name="cf-facts"
timestamp>="2026-08-07T09:00:00Z"
' --project=msklad-bi-prod --format=json --limit=200 --order=asc \
  > /Users/ilyasbazarov/Desktop/msklad_project/holika/worktrees/SALES-INGEST-PATCH-DEPLOY/reference/_scratch_SALES-INGEST-PATCH-DEPLOY_2026-08-07/step8_logs_raw.json

python3 - <<'PY'
import json
with open("/Users/ilyasbazarov/Desktop/msklad_project/holika/worktrees/SALES-INGEST-PATCH-DEPLOY/reference/_scratch_SALES-INGEST-PATCH-DEPLOY_2026-08-07/step8_logs_raw.json") as f:
    entries = json.load(f)
for e in entries:
    msg = e.get("textPayload") or e.get("jsonPayload", {}).get("message", "")
    if msg:
        print(e.get("timestamp"), "|", msg)
PY

echo "=== UTC anchor (end) ==="
date -u
echo "=== caller identity (end) ==="
gcloud auth list
