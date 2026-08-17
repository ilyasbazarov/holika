#!/usr/bin/env bash
set -euo pipefail

echo "=== UTC anchor (start) ==="
date -u
echo "=== gcloud auth list (start) ==="
gcloud auth list

echo "=== read-only: полный live describe cf-facts ДО деплоя, JSON в файл ==="
SCRATCH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
gcloud functions describe cf-facts --gen2 \
  --project=msklad-bi-prod --region=asia-east1 \
  --format=json > "$SCRATCH_DIR/predeploy_describe.json"

echo "=== ключевые параметры serviceConfig ==="
python3 -c "
import json
d = json.load(open('$SCRATCH_DIR/predeploy_describe.json'))
sc = d.get('serviceConfig', {})
print('revision:', sc.get('revision'))
print('availableMemory:', sc.get('availableMemory'))
print('timeoutSeconds:', sc.get('timeoutSeconds'))
print('serviceAccountEmail:', sc.get('serviceAccountEmail'))
print('maxInstanceCount:', sc.get('maxInstanceCount'))
print('minInstanceCount:', sc.get('minInstanceCount'))
print('ingressSettings:', sc.get('ingressSettings'))
print('environmentVariables:', sc.get('environmentVariables'))
print('secretEnvironmentVariables:', sc.get('secretEnvironmentVariables'))
print('runtime:', d.get('buildConfig', {}).get('runtime'))
print('entryPoint:', d.get('buildConfig', {}).get('entryPoint'))
print('allowUnauthenticated (invoker check via IAM, separate call below)')
"

echo "=== confirm traffic (still serving 00017-jon before deploy) ==="
gcloud run services describe cf-facts --region=asia-east1 --project=msklad-bi-prod --format="value(status.traffic)"

echo "=== UTC anchor (end) ==="
date -u
echo "=== gcloud auth list (end) ==="
gcloud auth list
