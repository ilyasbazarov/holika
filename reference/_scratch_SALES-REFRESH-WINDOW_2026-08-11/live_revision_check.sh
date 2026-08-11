#!/bin/bash
# Read-only свежий снимок живой ревизии cf-facts перед подготовкой запроса архитектору
# на рассмотрение мандата класса B (ADR-083 §2 требует не полагаться на прошлый MANIFEST.md
# без свежего describe). Класс A, ничего не мутирует.
set -euo pipefail

echo "=== date -u (start) ==="
date -u

echo "=== gcloud auth list (start) ==="
gcloud auth list

PROJECT="msklad-bi-prod"
REGION="asia-east1"

echo "=== gcloud run services describe cf-facts (обходной путь, functions describe даёт 403) ==="
gcloud run services describe cf-facts --project="$PROJECT" --region="$REGION" \
  --format="value(status.latestReadyRevisionName,status.traffic[0].revisionName,metadata.generation,status.conditions[0].lastTransitionTime)" 2>&1 || true

echo "=== gcloud functions list (справочно, метка ревизии) ==="
gcloud functions list --project="$PROJECT" --regions="$REGION" \
  --filter="name:cf-facts" --format="table(name,state,updateTime)" 2>&1 || true

echo "=== gcloud auth list (end) ==="
gcloud auth list

echo "=== date -u (end) ==="
date -u
