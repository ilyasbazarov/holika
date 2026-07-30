#!/usr/bin/env bash
set -uo pipefail
date -u
gcloud auth list

PROJECT=msklad-bi-prod
REGION=asia-east1
BASE_DIR="$(dirname "$0")/probe-remaining-cf"
mkdir -p "$BASE_DIR"
cd "$BASE_DIR"

for FN in cf-dim cf-dq cf-fx cf-alert; do
  echo "=== describe $FN (storageSource) ==="
  gcloud functions describe "$FN" --gen2 --region="$REGION" --project="$PROJECT" \
    --format="value(buildConfig.source.storageSource.bucket,buildConfig.source.storageSource.object,buildConfig.source.storageSource.generation)" 2>&1
done

echo "=== скачивание + грep 'invoiceout'/'invoice' по каждому архиву ==="
for FN in cf-dim cf-dq cf-fx cf-alert; do
  echo "--- $FN ---"
  LINE=$(gcloud functions describe "$FN" --gen2 --region="$REGION" --project="$PROJECT" \
    --format="value(buildConfig.source.storageSource.bucket,buildConfig.source.storageSource.object,buildConfig.source.storageSource.generation)" 2>&1)
  BUCKET=$(echo "$LINE" | awk '{print $1}')
  OBJECT=$(echo "$LINE" | awk '{print $2}')
  GEN=$(echo "$LINE" | awk '{print $3}')
  mkdir -p "$FN"
  gcloud storage cp "gs://${BUCKET}/${OBJECT}#${GEN}" "./${FN}/function-source.zip" 2>&1
  unzip -o "./${FN}/function-source.zip" -d "./${FN}/unpacked" 2>&1
  echo "files:"
  find "./${FN}/unpacked" -type f -name "*.py"
  echo "grep invoiceout/invoice:"
  grep -rln "invoiceout\|invoice" "./${FN}/unpacked"/*.py 2>&1 || echo "  (нет совпадений)"
done

gcloud auth list
date -u

echo "PATH_PRINTED: $BASE_DIR"
