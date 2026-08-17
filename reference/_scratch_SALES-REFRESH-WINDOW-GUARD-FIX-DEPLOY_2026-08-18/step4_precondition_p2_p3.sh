#!/usr/bin/env bash
set -euo pipefail

# Предусловия П2 (обслуживающая ревизия = cf-facts-00017-jon, 100%) и П3 (дрейф: sha256
# каждого файла обслуживающей ревизии сверен с master ДО правки). Read-only.

PROJECT="msklad-bi-prod"
REGION="asia-east1"
SCRATCH="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$SCRATCH/holika-prod"

echo "=== UTC anchor (start) ==="
date -u
echo "=== identity (start) ==="
gcloud auth list

echo "=== П2: обслуживающая ревизия (status.traffic) ==="
gcloud run services describe cf-facts --region="$REGION" --project="$PROJECT" \
  --format="value(status.traffic)" | tee "$SCRATCH/step4_traffic.txt"

echo "=== П2: полный describe для generation обслуживающей ревизии ==="
gcloud run revisions describe cf-facts-00017-jon --region="$REGION" --project="$PROJECT" \
  --format=json > "$SCRATCH/step4_revision_00017_describe.json"
python3 -c "
import json
d = json.load(open('$SCRATCH/step4_revision_00017_describe.json'))
print('name:', d.get('metadata', {}).get('name'))
"

echo "=== П3: скачиваем архив, закреплённый generation обслуживающей ревизии cf-facts-00017-jon ==="
GEN=1786546688061530
BUCKET=gcf-v2-sources-420804682491-asia-east1
OBJECT=cf-facts/function-source.zip
WORKDIR=$(mktemp -d)
cd "$WORKDIR"
gcloud storage cp "gs://${BUCKET}/${OBJECT}#${GEN}" ./archive.zip
mkdir extracted && cd extracted
unzip -q ../archive.zip
echo "=== файлы в архиве обслуживающей ревизии ==="
ls -la

echo "=== П3: sha256 каждого файла архива vs master код-репо (СВЕЖИЙ, до правки этой сессии) ==="
cd "$REPO_DIR"
git checkout master
ALL_MATCH=1
for f in bq_ops.py config.py fetch_perimeter.py helpers.py main.py; do
  A=$(sha256sum "$WORKDIR/extracted/$f" 2>/dev/null | cut -d' ' -f1)
  B=$(git show master:cf-facts/$f 2>/dev/null | sha256sum | cut -d' ' -f1)
  MATCH="MISMATCH"
  [ "$A" = "$B" ] && MATCH="match" || ALL_MATCH=0
  echo "$f: archive(00017-jon)=$A master=$B -> $MATCH"
done
echo "ALL_MATCH=$ALL_MATCH"

echo "=== workdir (не убирается, ADR-043) ==="
echo "$WORKDIR"

echo "=== UTC anchor (end) ==="
date -u
echo "=== identity (end) ==="
gcloud auth list
