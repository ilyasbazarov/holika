#!/bin/bash
set -euo pipefail
SCRATCH="reference/_scratch_DQ-SOURCE-CAPTURE_2026-08-02"
DEST="reference/code/cf-dq"

echo "=== date -u (start) ==="
date -u
echo "=== gcloud auth list (start) ==="
gcloud auth list

echo "=== gcloud functions describe cf-dq ==="
gcloud functions describe cf-dq --region=asia-east1 --gen2 --project=msklad-bi-prod --format=json \
  > "$SCRATCH/step1_describe.json" 2>"$SCRATCH/step1_describe.err" || {
    echo "describe FAILED, rc=$?"
    cat "$SCRATCH/step1_describe.err"
  }

echo "=== describe stderr ==="
cat "$SCRATCH/step1_describe.err" 2>/dev/null || true

STORAGE_SOURCE=$(python3 -c "
import json,sys
try:
    d=json.load(open('$SCRATCH/step1_describe.json'))
    print(d.get('buildConfig',{}).get('source',{}).get('storageSource',{}).get('bucket','') + '/' + d.get('buildConfig',{}).get('source',{}).get('storageSource',{}).get('object',''))
except Exception as e:
    print('ERROR:'+str(e), file=sys.stderr)
" 2>"$SCRATCH/step1_parse.err") || true

echo "STORAGE_SOURCE=$STORAGE_SOURCE"
cat "$SCRATCH/step1_parse.err" 2>/dev/null || true

if [ -n "${STORAGE_SOURCE:-}" ] && [ "$STORAGE_SOURCE" != "/" ]; then
  echo "=== gsutil cp gs://$STORAGE_SOURCE ==="
  gsutil cp "gs://$STORAGE_SOURCE" "$SCRATCH/function-source.zip" 2>"$SCRATCH/step1_gsutil.err" || {
    echo "gsutil cp FAILED"
    cat "$SCRATCH/step1_gsutil.err"
  }
  if [ -f "$SCRATCH/function-source.zip" ]; then
    echo "=== unzip ==="
    mkdir -p "$SCRATCH/source_unzipped"
    unzip -o "$SCRATCH/function-source.zip" -d "$SCRATCH/source_unzipped" > "$SCRATCH/step1_unzip.log"
    echo "=== contents ==="
    find "$SCRATCH/source_unzipped" -type f
  fi
else
  echo "STORAGE_SOURCE empty or malformed — direct path unavailable"
fi

echo "=== date -u (end) ==="
date -u
echo "=== gcloud auth list (end) ==="
gcloud auth list
