#!/usr/bin/env bash
set -euo pipefail

SCRATCH="reference/_scratch_SALES-PERIMETER-CADENCE-DEPLOY_2026-08-07"
PROJECT="msklad-bi-prod"
LOCATION="asia-east1"
WORKFLOW="msklad-pipeline-weekly"
BRANCH_FILE="$SCRATCH/holika-prod/workflows/msklad-pipeline-weekly.yaml"

echo "=== UTC anchor (start) ==="
date -u
echo "=== identity (start) ==="
gcloud auth list

echo "=== gcloud workflows describe (post-deploy) ==="
gcloud workflows describe "$WORKFLOW" \
  --location="$LOCATION" --project="$PROJECT" \
  --format=json > "$SCRATCH/step6_weekly_describe_postdeploy.json"

python3 - "$SCRATCH/step6_weekly_describe_postdeploy.json" "$SCRATCH/step6_weekly_readback_source.yaml" <<'PY'
import json, sys
with open(sys.argv[1]) as f:
    data = json.load(f)
src = data["sourceContents"]
with open(sys.argv[2], "w") as f:
    f.write(src)
print("revisionId=", data.get("revisionId"))
print("updateTime=", data.get("updateTime"))
PY

echo "=== sha256 read-back sourceContents ==="
shasum -a 256 "$SCRATCH/step6_weekly_readback_source.yaml"
echo "=== sha256 branch file ==="
shasum -a 256 "$BRANCH_FILE"

echo "=== byte-for-byte diff: read-back vs branch file ==="
diff "$SCRATCH/step6_weekly_readback_source.yaml" "$BRANCH_FILE" && echo "READBACK_DIFF=IDENTICAL" || echo "READBACK_DIFF=DIFFERS"

echo "=== confirm perimeter steps present + order ==="
grep -n "^      - step_" "$SCRATCH/step6_weekly_readback_source.yaml"

echo "=== syntax check (pyyaml) ==="
python3 -c "import yaml; yaml.safe_load(open('$SCRATCH/step6_weekly_readback_source.yaml')); print('YAML_OK')"

echo "=== confirm hourly workflow untouched ==="
gcloud workflows describe msklad-pipeline-hourly \
  --location="$LOCATION" --project="$PROJECT" \
  --format="value(revisionId,updateTime)"

echo "=== identity (end) ==="
gcloud auth list
echo "=== UTC anchor (end) ==="
date -u
