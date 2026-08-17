#!/usr/bin/env bash
set -euo pipefail

echo "=== UTC anchor (start) ==="
date -u
echo "=== gcloud auth list (start) ==="
gcloud auth list

SCRATCH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$SCRATCH_DIR/holika-prod"
ARCHIVE_DIR="$SCRATCH_DIR/serving_archive"
rm -rf "$ARCHIVE_DIR"
mkdir -p "$ARCHIVE_DIR"

echo "=== confirm serving revision + source pointer (read-only) ==="
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

echo "=== cross-check against serving traffic (must be cf-facts-00017-jon) ==="
gcloud run services describe cf-facts --project=msklad-bi-prod --region=asia-east1 \
  --format="value(status.traffic)"

echo "=== download archive by pinned generation ==="
gcloud storage cp "gs://${BUCKET}/${OBJECT}#${GENERATION}" "$ARCHIVE_DIR/function-source.zip"

cd "$ARCHIVE_DIR"
unzip -q function-source.zip -d unpacked
find unpacked -type f | sort

echo "=== sha256 of archive files ==="
cd unpacked
find . -type f | sort | xargs shasum -a 256

echo "=== sha256 of branch-base (543b6c1) files, cf-facts/ dir ==="
cd "$REPO_DIR/cf-facts"
find . -type f | sort | xargs shasum -a 256

echo "=== П3 comparison table ==="
cd "$ARCHIVE_DIR/unpacked"
ALL_MATCH=1
for f in $(find . -type f \( -name '*.py' -o -name 'requirements.txt' \) | sed 's|^\./||' | sort); do
  ARCHIVE_SHA=$(shasum -a 256 "$f" 2>/dev/null | awk '{print $1}')
  BRANCH_SHA=$(shasum -a 256 "$REPO_DIR/cf-facts/$f" 2>/dev/null | awk '{print $1}' || echo "MISSING")
  if [ "$ARCHIVE_SHA" = "$BRANCH_SHA" ]; then
    STATUS="MATCH"
  else
    STATUS="MISMATCH"
    ALL_MATCH=0
  fi
  printf '%-30s archive=%s base=%s %s\n' "$f" "$ARCHIVE_SHA" "$BRANCH_SHA" "$STATUS"
done
echo "ALL_MATCH=$ALL_MATCH"

echo "=== UTC anchor (end) ==="
date -u
echo "=== gcloud auth list (end) ==="
gcloud auth list
