#!/usr/bin/env bash
set -euo pipefail

echo "=== UTC anchor (start) ==="
date -u
echo "=== gcloud auth list (start) ==="
gcloud auth list

SCRATCH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== П2/дополнение: serviceConfig.revision (LATEST BUILD, может НЕ быть обслуживающей) ==="
gcloud functions describe cf-dq --gen2 --region=asia-east1 --project=msklad-bi-prod \
  --format="yaml(serviceConfig.revision,buildConfig.source.storageSource)"

echo "=== обслуживающая ревизия по трафику (истина) ==="
gcloud run services describe cf-dq --region=asia-east1 --project=msklad-bi-prod \
  --format="value(status.traffic)"

echo "=== revision cf-dq-00009-coy: образ контейнера ==="
gcloud run revisions describe cf-dq-00009-coy --region=asia-east1 --project=msklad-bi-prod \
  --format="yaml(metadata.creationTimestamp,spec.containers[0].image)"

IMAGE=$(gcloud run revisions describe cf-dq-00009-coy --region=asia-east1 --project=msklad-bi-prod \
  --format="value(spec.containers[0].image)")
echo "image=$IMAGE"

echo "=== revision cf-dq-00010-kiq: образ контейнера (для сравнения, НЕ обслуживает) ==="
gcloud run revisions describe cf-dq-00010-kiq --region=asia-east1 --project=msklad-bi-prod \
  --format="yaml(metadata.creationTimestamp,spec.containers[0].image)" || echo "(ревизия не найдена или удалена)"

echo "=== все генерации объекта function-source.zip в бакете сборки (для сопоставления с образом) ==="
gcloud storage ls -a "gs://gcf-v2-sources-420804682491-asia-east1/cf-dq/function-source.zip" \
  > "$SCRATCH_DIR/step2_all_generations.txt" || true
cat "$SCRATCH_DIR/step2_all_generations.txt"

echo "=== Cloud Build история для образа ревизии cf-dq-00009-coy ==="
gcloud builds list --project=msklad-bi-prod \
  --filter="images:*cf-dq*" \
  --format="table(id,createTime,status,images)" \
  --limit=20 > "$SCRATCH_DIR/step2_builds_list.txt" || true
cat "$SCRATCH_DIR/step2_builds_list.txt"

echo "=== UTC anchor (end) ==="
date -u
echo "=== gcloud auth list (end) ==="
gcloud auth list
