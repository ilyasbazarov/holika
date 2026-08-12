#!/usr/bin/env bash
set -euo pipefail

echo "=== UTC anchor (start) ==="
date -u
echo "=== gcloud auth (start) ==="
gcloud auth list

SRC=/Users/ilyasbazarov/Desktop/msklad_project/holika/worktrees/SALES-REFRESH-WINDOW-DEPLOY-FINAL/reference/_scratch_SALES-REFRESH-WINDOW-DEPLOY-FINAL_2026-08-12/holika-prod/cf-facts

echo "=== deploying cf-facts from --source=$SRC ==="
echo "=== параметры сверены с живым describe ДО деплоя (current_describe.json), не угадываются ==="
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
  --format=json > deploy_result.json

python3 -c "
import json
d = json.load(open('deploy_result.json'))
print('new revision:', d.get('serviceConfig', {}).get('revision'))
print('generation:', d.get('buildConfig', {}).get('source', {}).get('storageSource', {}).get('generation'))
print('update_time:', d.get('updateTime'))
"

echo "=== traffic status immediately after deploy (Cloud Functions deploy auto-routes 100% to new revision) ==="
gcloud run services describe cf-facts --region=asia-east1 --project=msklad-bi-prod --format="value(status.traffic)"

echo "=== UTC anchor (end) ==="
date -u
echo "=== gcloud auth (end) ==="
gcloud auth list
