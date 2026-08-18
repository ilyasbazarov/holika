#!/usr/bin/env bash
set -euo pipefail

echo "=== UTC anchor (start) ==="
date -u
echo "=== gcloud auth list (start) ==="
gcloud auth list

SCRATCH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$SCRATCH_DIR/holika-prod"
NEW_ARCHIVE_DIR="$SCRATCH_DIR/new_revision_archive"

echo "--- Пункт приёмки 1: sha256 архива новой ревизии против ветки деплоя ---"
GENERATION=$(gcloud functions describe cf-dq --gen2 --region=asia-east1 --project=msklad-bi-prod \
  --format="value(buildConfig.source.storageSource.generation)")
echo "generation=$GENERATION"

rm -rf "$NEW_ARCHIVE_DIR"
mkdir -p "$NEW_ARCHIVE_DIR"
gcloud storage cp "gs://gcf-v2-sources-420804682491-asia-east1/cf-dq/function-source.zip#${GENERATION}" \
  "$NEW_ARCHIVE_DIR/function-source.zip"
cd "$NEW_ARCHIVE_DIR"
unzip -q function-source.zip -d unpacked
echo "--- содержимое архива новой ревизии ---"
find unpacked -type f | sort

echo "--- sha256 архива ---"
cd unpacked
find . -type f | sort | xargs shasum -a 256

echo "--- sha256 ветки деплоя (cf-dq/) ---"
cd "$REPO_DIR/cf-dq"
find . -maxdepth 1 -type f \( -name '*.py' -o -name 'requirements.txt' \) | sort | xargs shasum -a 256

echo "--- сопоставление (архив vs ветка) ---"
ALL_MATCH=1
cd "$NEW_ARCHIVE_DIR/unpacked"
for f in $(find . -type f | sed 's|^\./||' | sort); do
  ARCHIVE_SHA=$(shasum -a 256 "$f" | awk '{print $1}')
  BRANCH_SHA=$(shasum -a 256 "$REPO_DIR/cf-dq/$f" 2>/dev/null | awk '{print $1}' || echo "MISSING")
  if [ "$ARCHIVE_SHA" = "$BRANCH_SHA" ]; then STATUS=MATCH; else STATUS=MISMATCH; ALL_MATCH=0; fi
  printf '%-20s archive=%s branch=%s %s\n' "$f" "$ARCHIVE_SHA" "$BRANCH_SHA" "$STATUS"
done
echo "ALL_MATCH=$ALL_MATCH"

echo "--- Пункт приёмки 2: обслуживающая ревизия = новая, percent=100 ---"
gcloud run services describe cf-dq --region=asia-east1 --project=msklad-bi-prod \
  --format="value(status.traffic)"

echo "=== UTC anchor (end) ==="
date -u
echo "=== gcloud auth list (end) ==="
gcloud auth list
