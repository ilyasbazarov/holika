#!/usr/bin/env bash
set -euo pipefail

echo "=== UTC anchor (start) ==="
date -u
echo "=== gcloud auth list (start) ==="
gcloud auth list

SCRATCH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$SCRATCH_DIR/holika-prod"
BRANCH=deploy/cf-facts-2026-08-18-guard-fix-f3-v2
SRC="$REPO_DIR/cf-facts"

cd "$REPO_DIR"
git checkout "$BRANCH"
echo "HEAD ветки деплоя: $(git rev-parse HEAD)"

echo "=== push ветки в origin (владелец подтвердил в чате) ==="
git push origin "$BRANCH"

echo "=== gcloud functions deploy cf-facts, --source=$SRC ==="
echo "=== флаги сверены с живым describe ДО деплоя (step8_run.log), не угадываются ==="
gcloud functions deploy cf-facts \
  --gen2 \
  --region=asia-east1 \
  --project=msklad-bi-prod \
  --source="$SRC" \
  --runtime=python312 \
  --entry-point=main \
  --trigger-http \
  --no-allow-unauthenticated \
  --memory=2048MB \
  --timeout=540s \
  --service-account=etl-sa@msklad-bi-prod.iam.gserviceaccount.com \
  --ingress-settings=all \
  --max-instances=5 \
  --set-env-vars=LOG_EXECUTION_ID=true \
  --format=json > "$SCRATCH_DIR/deploy_result.json"

python3 -c "
import json
d = json.load(open('$SCRATCH_DIR/deploy_result.json'))
print('new revision:', d.get('serviceConfig', {}).get('revision'))
print('generation:', d.get('buildConfig', {}).get('source', {}).get('storageSource', {}).get('generation'))
print('update_time:', d.get('updateTime'))
"

echo "=== traffic status сразу после деплоя ==="
gcloud run services describe cf-facts --region=asia-east1 --project=msklad-bi-prod --format="value(status.traffic)"

echo "=== UTC anchor (end) ==="
date -u
echo "=== gcloud auth list (end) ==="
gcloud auth list
