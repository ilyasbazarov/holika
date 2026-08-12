#!/bin/bash
set -euo pipefail
echo "=== date -u (start) ==="
date -u
echo "=== gcloud auth list (start) ==="
gcloud auth list

echo "=== gcloud run services describe cf-dq (status.traffic) ==="
gcloud run services describe cf-dq --region=asia-east1 --project=msklad-bi-prod \
  --format="yaml(status.traffic,status.latestReadyRevisionName,status.latestCreatedRevisionName)"

echo "=== obslugivayuschaya revision name (status.traffic, percent=100) ==="
SERVING_REV=$(gcloud run services describe cf-dq --region=asia-east1 --project=msklad-bi-prod \
  --format="value(status.traffic[0].revisionName)")
echo "SERVING_REV=${SERVING_REV}"

echo "=== gcloud run revisions describe (source generation of serving revision) ==="
gcloud run revisions describe "${SERVING_REV}" --region=asia-east1 --project=msklad-bi-prod \
  --format="yaml(metadata.name,metadata.creationTimestamp,metadata.annotations)" > /tmp/serving_rev_describe.yaml
cat /tmp/serving_rev_describe.yaml

echo "=== gcloud functions describe cf-dq (for storageSource generation, cross-check only) ==="
gcloud functions describe cf-dq --gen2 --region=asia-east1 --project=msklad-bi-prod \
  --format="yaml(serviceConfig.revision,buildConfig.source.storageSource)"

echo "=== gcloud auth list (end) ==="
gcloud auth list
echo "=== date -u (end) ==="
date -u
