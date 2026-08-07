#!/usr/bin/env bash
set -euo pipefail

SCRATCH="reference/_scratch_SALES-PERIMETER-CADENCE-DEPLOY_2026-08-07"
PROJECT="msklad-bi-prod"
LOCATION="asia-east1"
WORKFLOW="msklad-pipeline-weekly"
REPO_URL="https://github.com/ilyasbazarov/holika-prod"

echo "=== UTC anchor (start) ==="
date -u
echo "=== identity (start) ==="
gcloud auth list

echo "=== gcloud workflows describe (live) ==="
gcloud workflows describe "$WORKFLOW" \
  --location="$LOCATION" --project="$PROJECT" \
  --format=json > "$SCRATCH/step1_weekly_describe.json"

python3 - "$SCRATCH/step1_weekly_describe.json" "$SCRATCH/step1_weekly_live_source.yaml" <<'PY'
import json, sys
with open(sys.argv[1]) as f:
    data = json.load(f)
src = data["sourceContents"]
with open(sys.argv[2], "w") as f:
    f.write(src)
print("revisionId=", data.get("revisionId"))
print("updateTime=", data.get("updateTime"))
PY

echo "=== sha256 of live sourceContents ==="
shasum -a 256 "$SCRATCH/step1_weekly_live_source.yaml"

echo "=== clone code-repo master (read-only, shallow) ==="
rm -rf "$SCRATCH/holika-prod"
git clone --depth=1 --branch master "$REPO_URL" "$SCRATCH/holika-prod"

echo "=== locate weekly workflow file in code-repo ==="
find "$SCRATCH/holika-prod/workflows" -maxdepth 1 -type f -iname "*weekly*"

echo "=== byte-for-byte diff: live sourceContents vs master code-repo ==="
WEEKLY_FILE=$(find "$SCRATCH/holika-prod/workflows" -maxdepth 1 -type f -iname "*weekly*" | head -1)
echo "master file: $WEEKLY_FILE"
diff "$SCRATCH/step1_weekly_live_source.yaml" "$WEEKLY_FILE" && echo "DIFF_RESULT=IDENTICAL" || echo "DIFF_RESULT=DIFFERS"
shasum -a 256 "$WEEKLY_FILE"

echo "=== search for 'perimeter' in live sourceContents (expect 0 matches — cadence not yet wired) ==="
grep -n "perimeter" "$SCRATCH/step1_weekly_live_source.yaml" || echo "0 matches"

echo "=== compare live source vs patched snapshot reference/code/cf-facts/workflow_weekly.yaml ==="
diff "$SCRATCH/step1_weekly_live_source.yaml" "reference/code/cf-facts/workflow_weekly.yaml" && echo "SNAPSHOT_DIFF=IDENTICAL" || echo "SNAPSHOT_DIFF=DIFFERS_AS_EXPECTED_PATCH"

echo "=== identity (end) ==="
gcloud auth list
echo "=== UTC anchor (end) ==="
date -u

echo "SCRATCH_PATH=$SCRATCH"
