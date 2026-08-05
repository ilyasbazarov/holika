#!/usr/bin/env bash
set -euo pipefail
SCRATCH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG="$SCRATCH/step1_run.log"

{
echo "=== date -u (start) ==="
date -u
echo "=== gcloud auth list (start) ==="
gcloud auth list

echo "=== describe msklad-pipeline-hourly ==="
gcloud workflows describe msklad-pipeline-hourly \
  --location=asia-east1 --project=msklad-bi-prod --format=json \
  > "$SCRATCH/hourly_describe.json"
cat "$SCRATCH/hourly_describe.json" | python3 -c "import json,sys; d=json.load(sys.stdin); print('revisionId=', d.get('revisionId')); print('updateTime=', d.get('updateTime')); print('state=', d.get('state')); print('serviceAccount=', d.get('serviceAccount'))"
python3 -c "import json; d=json.load(open('$SCRATCH/hourly_describe.json')); open('$SCRATCH/hourly_live_sourceContents.yaml','w').write(d['sourceContents'])"

echo "=== describe msklad-pipeline-weekly ==="
gcloud workflows describe msklad-pipeline-weekly \
  --location=asia-east1 --project=msklad-bi-prod --format=json \
  > "$SCRATCH/weekly_describe.json"
cat "$SCRATCH/weekly_describe.json" | python3 -c "import json,sys; d=json.load(sys.stdin); print('revisionId=', d.get('revisionId')); print('updateTime=', d.get('updateTime')); print('state=', d.get('state')); print('serviceAccount=', d.get('serviceAccount'))"
python3 -c "import json; d=json.load(open('$SCRATCH/weekly_describe.json')); open('$SCRATCH/weekly_live_sourceContents.yaml','w').write(d['sourceContents'])"

echo "=== sha256 живых снимков ==="
shasum -a 256 "$SCRATCH/hourly_live_sourceContents.yaml" "$SCRATCH/weekly_live_sourceContents.yaml"

echo "=== diff <(sort живой) <(sort патч) — hourly ==="
diff <(sort "$SCRATCH/hourly_live_sourceContents.yaml") <(sort ../code/cf-facts/workflow_hourly.yaml) && echo "HOURLY: diff sort — ПУСТО (множество строк тождественно)" || echo "HOURLY: diff sort — ЕСТЬ РАЗЛИЧИЯ"

echo "=== diff <(sort живой) <(sort патч) — weekly ==="
diff <(sort "$SCRATCH/weekly_live_sourceContents.yaml") <(sort ../code/cf-facts/workflow_weekly.yaml) && echo "WEEKLY: diff sort — ПУСТО (множество строк тождественно)" || echo "WEEKLY: diff sort — ЕСТЬ РАЗЛИЧИЯ"

echo "=== сверка живого с копией снимка 2026-08-02 (если найдена) ==="
find .. -iname "*step2_hourly_workflow.yaml" -o -iname "*step2_weekly_workflow.yaml" 2>/dev/null || true

echo "=== gcloud auth list (end) ==="
gcloud auth list
echo "=== date -u (end) ==="
date -u
} > "$LOG" 2>&1

echo "LOG: $LOG"
