#!/usr/bin/env bash
set -euo pipefail

# Предусловие П1 (guard_fix_deploy_mandate_2026-08-18.md §3): живые sourceContents обоих
# Cloud Workflow обязаны нести run_id: ${run_id} в body у step_promote И
# step_perimeter_promote. Read-only. Отсутствие хотя бы в одном месте — СТОП.

PROJECT="msklad-bi-prod"
LOCATION="asia-east1"
SCRATCH="$(cd "$(dirname "$0")" && pwd)"

echo "=== UTC anchor (start) ==="
date -u
echo "=== identity (start) ==="
gcloud auth list

for WORKFLOW in msklad-pipeline-hourly msklad-pipeline-weekly; do
  echo "=== gcloud workflows describe (live): $WORKFLOW ==="
  gcloud workflows describe "$WORKFLOW" \
    --location="$LOCATION" --project="$PROJECT" \
    --format=json > "$SCRATCH/step1_${WORKFLOW}_describe.json"

  python3 - "$SCRATCH/step1_${WORKFLOW}_describe.json" "$SCRATCH/step1_${WORKFLOW}_live_source.yaml" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
src = d.get("sourceContents", "")
open(sys.argv[2], "w").write(src)
print("revisionId=", d.get("revisionId"))
print("updateTime=", d.get("updateTime"))
PY

  echo "=== source lines with numbers, filtered around step_promote / step_perimeter_promote for $WORKFLOW ==="
  grep -n "step_promote\|step_perimeter_promote\|run_id" "$SCRATCH/step1_${WORKFLOW}_live_source.yaml" || echo "NO MATCHES"
done

echo "=== UTC anchor (end) ==="
date -u
echo "=== identity (end) ==="
gcloud auth list
