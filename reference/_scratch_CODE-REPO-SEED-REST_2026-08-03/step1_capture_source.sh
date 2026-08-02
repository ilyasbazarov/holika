#!/usr/bin/env bash
set -euo pipefail

PROJECT=msklad-bi-prod
REGION=asia-east1
WORKDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTDIR="$WORKDIR/source_unzipped_$(date -u +%Y%m%dT%H%M%SZ 2>/dev/null || true)"
mkdir -p "$OUTDIR"

echo "=== UTC ANCHOR (start) ==="
date -u
echo "=== CALLER IDENTITY (start) ==="
gcloud auth list

echo
echo "=== cf-facts: gcloud functions describe (expect possible 403) ==="
if gcloud functions describe cf-facts --gen2 --region="$REGION" --project="$PROJECT" --format=json > "$WORKDIR/cf-facts_describe.json" 2> "$WORKDIR/cf-facts_describe.err"; then
  echo "cf-facts: functions describe SUCCEEDED (direct path)"
  CF_FACTS_METHOD="direct (gcloud functions describe)"
else
  echo "cf-facts: functions describe FAILED, see cf-facts_describe.err; falling back to run services describe"
  cat "$WORKDIR/cf-facts_describe.err"
  CF_FACTS_METHOD="fallback (gcloud run services describe)"
fi

echo
echo "=== cf-facts: gcloud run services describe (fallback / cross-check) ==="
gcloud run services describe cf-facts --region="$REGION" --project="$PROJECT" --format=json > "$WORKDIR/cf-facts_run_describe.json"
echo "cf-facts run services describe: OK"

echo
echo "=== cf-dq: gcloud functions describe (expect direct success) ==="
gcloud functions describe cf-dq --gen2 --region="$REGION" --project="$PROJECT" --format=json > "$WORKDIR/cf-dq_describe.json"
echo "cf-dq: functions describe SUCCEEDED"

echo
echo "=== Extracting revision / storageSource for cf-facts ==="
if [ -s "$WORKDIR/cf-facts_describe.json" ] && [ "$CF_FACTS_METHOD" = "direct (gcloud functions describe)" ]; then
  CF_FACTS_REV=$(python3 -c "import json;d=json.load(open('$WORKDIR/cf-facts_describe.json'));print(d.get('serviceConfig',{}).get('revision',''))")
  CF_FACTS_SRC_URI=$(python3 -c "import json;d=json.load(open('$WORKDIR/cf-facts_describe.json'));b=d.get('buildConfig',{}).get('source',{}).get('storageSource',{});print('gs://%s/%s'%(b.get('bucket',''),b.get('object','')))")
  CF_FACTS_GEN=$(python3 -c "import json;d=json.load(open('$WORKDIR/cf-facts_describe.json'));print(d.get('buildConfig',{}).get('source',{}).get('storageSource',{}).get('generation',''))")
else
  CF_FACTS_REV=$(python3 -c "import json;d=json.load(open('$WORKDIR/cf-facts_run_describe.json'));print(d.get('status',{}).get('latestReadyRevisionName','') or d.get('status',{}).get('latestCreatedRevisionName',''))")
  CF_FACTS_SRC_URI="UNKNOWN_VIA_RUN_DESCRIBE"
  CF_FACTS_GEN="UNKNOWN_VIA_RUN_DESCRIBE"
fi
echo "cf-facts revision: $CF_FACTS_REV"
echo "cf-facts source uri (from describe path used): $CF_FACTS_SRC_URI"
echo "cf-facts generation: $CF_FACTS_GEN"

echo
echo "=== Extracting revision / storageSource for cf-dq ==="
CF_DQ_REV=$(python3 -c "import json;d=json.load(open('$WORKDIR/cf-dq_describe.json'));print(d.get('serviceConfig',{}).get('revision',''))")
CF_DQ_SRC_URI=$(python3 -c "import json;d=json.load(open('$WORKDIR/cf-dq_describe.json'));b=d.get('buildConfig',{}).get('source',{}).get('storageSource',{});print('gs://%s/%s'%(b.get('bucket',''),b.get('object','')))")
CF_DQ_GEN=$(python3 -c "import json;d=json.load(open('$WORKDIR/cf-dq_describe.json'));print(d.get('buildConfig',{}).get('source',{}).get('storageSource',{}).get('generation',''))")
echo "cf-dq revision: $CF_DQ_REV"
echo "cf-dq source uri: $CF_DQ_SRC_URI"
echo "cf-dq generation: $CF_DQ_GEN"

echo
echo "=== Downloading source archives ==="
mkdir -p "$OUTDIR/cf-facts" "$OUTDIR/cf-dq"

if [ "$CF_FACTS_SRC_URI" != "UNKNOWN_VIA_RUN_DESCRIBE" ]; then
  gcloud storage cp "${CF_FACTS_SRC_URI}#${CF_FACTS_GEN}" "$OUTDIR/cf-facts/function-source.zip" --project="$PROJECT"
  echo "cf-facts archive downloaded via storageSource"
else
  echo "cf-facts: no storageSource from functions describe (fell back to run describe) — attempting known bucket pattern"
  CF_FACTS_SRC_URI_GUESS="gs://gcf-v2-sources-420804682491-${REGION}/cf-facts/function-source.zip"
  if gcloud storage cp "$CF_FACTS_SRC_URI_GUESS" "$OUTDIR/cf-facts/function-source.zip" --project="$PROJECT" 2> "$WORKDIR/cf-facts_storage_cp.err"; then
    echo "cf-facts archive downloaded via guessed bucket pattern (no generation pinned — CURRENT object)"
    CF_FACTS_SRC_URI="$CF_FACTS_SRC_URI_GUESS"
    CF_FACTS_GEN="UNPINNED_current_object"
  else
    echo "cf-facts archive download FAILED via guessed pattern too"
    cat "$WORKDIR/cf-facts_storage_cp.err"
    exit 1
  fi
fi

gcloud storage cp "${CF_DQ_SRC_URI}#${CF_DQ_GEN}" "$OUTDIR/cf-dq/function-source.zip" --project="$PROJECT"
echo "cf-dq archive downloaded via storageSource"

echo
echo "=== Unzipping ==="
(cd "$OUTDIR/cf-facts" && unzip -o function-source.zip -d unzipped > /dev/null && find unzipped -type f | sort)
(cd "$OUTDIR/cf-dq" && unzip -o function-source.zip -d unzipped > /dev/null && find unzipped -type f | sort)

echo
echo "=== sha256 (cf-facts) ==="
(cd "$OUTDIR/cf-facts/unzipped" && find . -type f | sort | xargs shasum -a 256)

echo
echo "=== sha256 (cf-dq) ==="
(cd "$OUTDIR/cf-dq/unzipped" && find . -type f | sort | xargs shasum -a 256)

echo
echo "=== SUMMARY ==="
echo "OUTDIR=$OUTDIR"
echo "CF_FACTS_REV=$CF_FACTS_REV"
echo "CF_FACTS_METHOD=$CF_FACTS_METHOD"
echo "CF_FACTS_SRC_URI=$CF_FACTS_SRC_URI"
echo "CF_FACTS_GEN=$CF_FACTS_GEN"
echo "CF_DQ_REV=$CF_DQ_REV"
echo "CF_DQ_SRC_URI=$CF_DQ_SRC_URI"
echo "CF_DQ_GEN=$CF_DQ_GEN"

echo
echo "=== UTC ANCHOR (end) ==="
date -u
echo "=== CALLER IDENTITY (end) ==="
gcloud auth list
