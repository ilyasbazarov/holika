#!/usr/bin/env bash
set -euo pipefail

echo "=== UTC anchor (start) ==="
date -u
echo "=== gcloud auth list (start) ==="
gcloud auth list

SCRATCH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$SCRATCH_DIR/holika-prod"
BRANCH=deploy/cf-dq-2026-08-18-freshness-wire-v2
SRC="$REPO_DIR/cf-dq"

cd "$REPO_DIR"
git checkout "$BRANCH"
echo "HEAD ветки деплоя: $(git rev-parse HEAD)"

echo "=== push ветки в origin (владелец подтвердил явным «да» в чате) ==="
git push origin "$BRANCH"

echo "=== gcloud functions deploy cf-dq, --source=$SRC ==="
echo "=== флаги сверены с живым describe ДО деплоя (step12_run.log), не угадываются ==="
gcloud functions deploy cf-dq \
  --gen2 \
  --region=asia-east1 \
  --project=msklad-bi-prod \
  --source="$SRC" \
  --runtime=python312 \
  --entry-point=main \
  --trigger-http \
  --no-allow-unauthenticated \
  --memory=512Mi \
  --timeout=120s \
  --min-instances=1 \
  --max-instances=6 \
  --concurrency=1 \
  --service-account=etl-sa@msklad-bi-prod.iam.gserviceaccount.com \
  --ingress-settings=all \
  --set-env-vars=LOG_EXECUTION_ID=true \
  --set-secrets=MSKLAD_TOKEN=msklad-token:latest \
  --format=json > "$SCRATCH_DIR/step13_deploy_result.json"

python3 -c "
import json
d = json.load(open('$SCRATCH_DIR/step13_deploy_result.json'))
print('new revision:', d.get('serviceConfig', {}).get('revision'))
print('generation:', d.get('buildConfig', {}).get('source', {}).get('storageSource', {}).get('generation'))
print('state:', d.get('state'))
print('update_time:', d.get('updateTime'))
"

echo "=== traffic status сразу после деплоя ==="
gcloud run services describe cf-dq --region=asia-east1 --project=msklad-bi-prod --format="value(status.traffic)"

echo "=== UTC anchor (end) ==="
date -u
echo "=== gcloud auth list (end) ==="
gcloud auth list
