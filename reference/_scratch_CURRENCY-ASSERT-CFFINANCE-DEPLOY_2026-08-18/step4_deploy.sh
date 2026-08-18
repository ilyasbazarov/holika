#!/usr/bin/env bash
set -euo pipefail
echo "=== UTC anchor (start) ==="; date -u
echo "=== gcloud auth list (start) ==="; gcloud auth list
SCRATCH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$SCRATCH/holika-prod"
BRANCH=deploy/cf-finance-2026-08-18-currency-assert
SRC="$REPO/cf-finance"

cd "$REPO"; git checkout -q "$BRANCH"
echo "HEAD ветки деплоя: $(git rev-parse HEAD)"

echo; echo "=== push ветки в origin (провенанс «ревизия ↔ коммит») ==="
git push -q origin "$BRANCH" && echo "  ветка запушена"

echo; echo "=== gcloud functions deploy cf-finance --source=$SRC ==="
echo "=== флаги сняты с живого describe (step1_run.log), не угаданы ==="
gcloud functions deploy cf-finance \
  --gen2 \
  --region=asia-east1 \
  --project=msklad-bi-prod \
  --source="$SRC" \
  --runtime=python312 \
  --entry-point=main \
  --trigger-http \
  --no-allow-unauthenticated \
  --memory=512MB \
  --timeout=1800s \
  --service-account=etl-sa@msklad-bi-prod.iam.gserviceaccount.com \
  --ingress-settings=all \
  --max-instances=16 \
  --set-env-vars=LOG_EXECUTION_ID=true \
  --format=json > "$SCRATCH/deploy_result.json"

python3 -c "
import json; d=json.load(open('$SCRATCH/deploy_result.json'))
sc,bc=d.get('serviceConfig',{}),d.get('buildConfig',{})
ss=bc.get('source',{}).get('storageSource',{})
print('  новая ревизия :', sc.get('revision'))
print('  state         :', d.get('state'))
print('  updateTime    :', d.get('updateTime'))
print('  generation    :', ss.get('generation'))
"
echo "=== UTC anchor (end) ==="; date -u
echo "=== gcloud auth list (end) ==="; gcloud auth list
