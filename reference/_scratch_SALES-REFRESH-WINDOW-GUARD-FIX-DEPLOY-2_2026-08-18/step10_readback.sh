#!/usr/bin/env bash
set -euo pipefail

echo "=== UTC anchor (start) ==="
date -u
echo "=== gcloud auth list (start) ==="
gcloud auth list

SCRATCH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$SCRATCH_DIR/holika-prod"
NEW_ARCHIVE_DIR="$SCRATCH_DIR/new_revision_archive"
rm -rf "$NEW_ARCHIVE_DIR"
mkdir -p "$NEW_ARCHIVE_DIR"

echo "=== confirm новая ревизия (read-only describe) ==="
gcloud functions describe cf-facts --gen2 \
  --project=msklad-bi-prod --region=asia-east1 \
  --format="yaml(serviceConfig.revision,buildConfig.source.storageSource)"

BUCKET=$(gcloud functions describe cf-facts --gen2 \
  --project=msklad-bi-prod --region=asia-east1 \
  --format="value(buildConfig.source.storageSource.bucket)")
OBJECT=$(gcloud functions describe cf-facts --gen2 \
  --project=msklad-bi-prod --region=asia-east1 \
  --format="value(buildConfig.source.storageSource.object)")
GENERATION=$(gcloud functions describe cf-facts --gen2 \
  --project=msklad-bi-prod --region=asia-east1 \
  --format="value(buildConfig.source.storageSource.generation)")
echo "bucket=$BUCKET object=$OBJECT generation=$GENERATION"

echo "=== скачивание архива по закреплённому generation ==="
gcloud storage cp "gs://${BUCKET}/${OBJECT}#${GENERATION}" "$NEW_ARCHIVE_DIR/function-source.zip"
cd "$NEW_ARCHIVE_DIR"
unzip -q function-source.zip -d unpacked
echo "=== состав архива ==="
find unpacked -type f | sort

echo "=== мусор (.bak/__pycache__/.DS_Store/src.zip/patch_*.py) — ожидание: 0 совпадений ==="
find unpacked -type f \( -name '*.bak' -o -name '__pycache__' -o -name '.DS_Store' -o -name 'src.zip' -o -name 'patch_*.py' -o -name '*.pyc' \) | sort || true

echo "=== sha256 архива против ветки деплоя (HEAD, коммит после патча) ==="
cd unpacked
ALL_MATCH=1
for f in $(find . -type f | sed 's|^\./||' | sort); do
  ARCHIVE_SHA=$(shasum -a 256 "$f" | awk '{print $1}')
  BRANCH_SHA=$(shasum -a 256 "$REPO_DIR/cf-facts/$f" 2>/dev/null | awk '{print $1}' || echo "MISSING_IN_BRANCH")
  if [ "$ARCHIVE_SHA" = "$BRANCH_SHA" ]; then STATUS="MATCH"; else STATUS="MISMATCH"; ALL_MATCH=0; fi
  printf '%-30s archive=%s branch=%s %s\n' "$f" "$ARCHIVE_SHA" "$BRANCH_SHA" "$STATUS"
done
echo "ALL_MATCH=$ALL_MATCH"

echo "=== traffic всё ещё на старой ревизии (ожидание до переключения) ==="
gcloud run services describe cf-facts --region=asia-east1 --project=msklad-bi-prod --format="value(status.traffic)"

echo "=== UTC anchor (end) ==="
date -u
echo "=== gcloud auth list (end) ==="
gcloud auth list
