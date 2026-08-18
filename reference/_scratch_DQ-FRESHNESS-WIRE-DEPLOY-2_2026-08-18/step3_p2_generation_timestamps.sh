#!/usr/bin/env bash
set -euo pipefail

echo "=== UTC anchor (start) ==="
date -u
echo "=== gcloud auth list (start) ==="
gcloud auth list

SCRATCH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== timeCreated по обеим генерациям объекта function-source.zip ==="
for GEN in 1786561996565446 1786993415115340; do
  echo "--- generation $GEN ---"
  gcloud storage objects describe "gs://gcf-v2-sources-420804682491-asia-east1/cf-dq/function-source.zip#${GEN}" \
    --format="yaml(timeCreated,size,md5Hash)"
done

echo "=== revision cf-dq-00009-coy creationTimestamp (для сопоставления) ==="
gcloud run revisions describe cf-dq-00009-coy --region=asia-east1 --project=msklad-bi-prod \
  --format="value(metadata.creationTimestamp)"

echo "=== revision cf-dq-00010-kiq creationTimestamp (для сопоставления) ==="
gcloud run revisions describe cf-dq-00010-kiq --region=asia-east1 --project=msklad-bi-prod \
  --format="value(metadata.creationTimestamp)"

echo "=== UTC anchor (end) ==="
date -u
echo "=== gcloud auth list (end) ==="
gcloud auth list
