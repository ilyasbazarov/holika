#!/usr/bin/env bash
# ADR-152 — деплой cf-dq из выкаченной ветки deploy/cf-dq-2026-08-10-fail-open.
# Владелец подтвердил действие отдельным сообщением («Да, деплой»).
set -euo pipefail

BRANCH_DIR="$1"   # каталог выкаченной ветки код-репо (holika-prod)

echo "=== UTC-якорь (начало) ==="
date -u

echo
echo "=== личность вызывающего (начало) ==="
gcloud auth list

echo
echo "=== ветка/коммит источника ==="
git -C "$BRANCH_DIR" rev-parse --abbrev-ref HEAD
git -C "$BRANCH_DIR" rev-parse HEAD

echo
echo "=== деплой cf-dq (--source=$BRANCH_DIR/cf-dq) ==="
gcloud functions deploy cf-dq \
  --gen2 --region=asia-east1 --project=msklad-bi-prod \
  --runtime=python312 --entry-point=main \
  --source="$BRANCH_DIR/cf-dq" \
  --trigger-http \
  --service-account=etl-sa@msklad-bi-prod.iam.gserviceaccount.com \
  --memory=512Mi --timeout=120s \
  --min-instances=1 --max-instances=6 \
  --ingress-settings=all \
  --set-env-vars=LOG_EXECUTION_ID=true \
  --format=json > /tmp/cf_dq_deploy_result.json 2>&1 || { cat /tmp/cf_dq_deploy_result.json; echo "DEPLOY FAILED rc=$?"; exit 1; }

echo
echo "=== результат деплоя (сводка) ==="
python3 -c "
import json
d = json.load(open('/tmp/cf_dq_deploy_result.json'))
sc = d.get('serviceConfig', {})
bc = d.get('buildConfig', {})
print('revision:', sc.get('revision'))
print('updateTime:', d.get('updateTime'))
print('state:', d.get('state'))
print('storageSource:', bc.get('source', {}).get('storageSource', {}))
"

echo
echo "=== UTC-якорь (конец) ==="
date -u

echo
echo "=== личность вызывающего (конец) ==="
gcloud auth list
