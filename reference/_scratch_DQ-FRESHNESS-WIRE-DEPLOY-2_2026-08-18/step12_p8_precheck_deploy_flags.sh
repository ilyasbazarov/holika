#!/usr/bin/env bash
set -euo pipefail

echo "=== UTC anchor (start) ==="
date -u
echo "=== gcloud auth list (start) ==="
gcloud auth list

SCRATCH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== IAM invoker policy на cf-dq (allow-unauthenticated или нет) ==="
gcloud run services get-iam-policy cf-dq --region=asia-east1 --project=msklad-bi-prod \
  --format=json > "$SCRATCH_DIR/step12_iam_policy.json"
cat "$SCRATCH_DIR/step12_iam_policy.json"

echo "--- allUsers в bindings? ---"
grep -c "allUsers" "$SCRATCH_DIR/step12_iam_policy.json" || echo "0"

echo "=== trigger type (http) ==="
gcloud functions describe cf-dq --gen2 --region=asia-east1 --project=msklad-bi-prod \
  --format="yaml(eventTrigger)"
echo "(пусто выше = HTTP-триггер, не событийный)"

echo "=== полный набор флагов конфигурации функции (сверка перед деплоем) ==="
gcloud functions describe cf-dq --gen2 --region=asia-east1 --project=msklad-bi-prod \
  --format="yaml(serviceConfig.availableMemory,serviceConfig.availableCpu,serviceConfig.timeoutSeconds,serviceConfig.maxInstanceCount,serviceConfig.minInstanceCount,serviceConfig.maxInstanceRequestConcurrency,serviceConfig.serviceAccountEmail,serviceConfig.ingressSettings,serviceConfig.environmentVariables,serviceConfig.secretEnvironmentVariables,buildConfig.runtime,buildConfig.entryPoint)"

echo "=== UTC anchor (end) ==="
date -u
echo "=== gcloud auth list (end) ==="
gcloud auth list
