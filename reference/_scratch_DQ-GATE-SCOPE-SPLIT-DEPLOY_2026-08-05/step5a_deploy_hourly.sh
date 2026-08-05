#!/usr/bin/env bash
set -euo pipefail
SCRATCH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BRANCH_DIR="/private/tmp/claude-501/-Users-ilyasbazarov-Desktop-msklad-project-holika-worktrees-DQ-GATE-SCOPE-SPLIT-DEPLOY/1b6bdc50-8e61-48cc-ad94-91f7e77f23a3/scratchpad/holika-prod"
LOG="$SCRATCH/step5a_deploy_hourly_run.log"

{
echo "=== date -u (start) ==="
date -u
echo "=== gcloud auth list (start) ==="
gcloud auth list

echo "=== gcloud workflows deploy msklad-pipeline-hourly ==="
gcloud workflows deploy msklad-pipeline-hourly \
  --location=asia-east1 \
  --project=msklad-bi-prod \
  --source="$BRANCH_DIR/workflows/msklad-pipeline-hourly.yaml" \
  --service-account=etl-sa@msklad-bi-prod.iam.gserviceaccount.com

echo "=== gcloud auth list (end) ==="
gcloud auth list
echo "=== date -u (end) ==="
date -u
} > "$LOG" 2>&1

echo "LOG: $LOG"
