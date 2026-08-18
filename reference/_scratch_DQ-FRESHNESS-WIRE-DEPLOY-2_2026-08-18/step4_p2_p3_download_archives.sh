#!/usr/bin/env bash
set -euo pipefail

echo "=== UTC anchor (start) ==="
date -u
echo "=== gcloud auth list (start) ==="
gcloud auth list

SCRATCH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== full object metadata, both generations (all fields) ==="
for GEN in 1786561996565446 1786993415115340; do
  echo "--- generation $GEN (full json) ---"
  gcloud storage objects describe "gs://gcf-v2-sources-420804682491-asia-east1/cf-dq/function-source.zip#${GEN}" \
    --format=json
done

echo "=== download OLDER generation (candidate: serving cf-dq-00009-coy) ==="
OLDER_DIR="$SCRATCH_DIR/archive_older_gen"
rm -rf "$OLDER_DIR"
mkdir -p "$OLDER_DIR"
gcloud storage cp "gs://gcf-v2-sources-420804682491-asia-east1/cf-dq/function-source.zip#1786561996565446" \
  "$OLDER_DIR/function-source.zip"
cd "$OLDER_DIR"
unzip -q function-source.zip -d unpacked
echo "--- contents (older) ---"
find unpacked -type f | sort
echo "--- sha256 (older) ---"
cd unpacked
find . -type f | sort | xargs shasum -a 256

echo "=== download NEWER generation (candidate: latest build cf-dq-00010-kiq) ==="
NEWER_DIR="$SCRATCH_DIR/archive_newer_gen"
rm -rf "$NEWER_DIR"
mkdir -p "$NEWER_DIR"
gcloud storage cp "gs://gcf-v2-sources-420804682491-asia-east1/cf-dq/function-source.zip#1786993415115340" \
  "$NEWER_DIR/function-source.zip"
cd "$NEWER_DIR"
unzip -q function-source.zip -d unpacked
echo "--- contents (newer) ---"
find unpacked -type f | sort
echo "--- sha256 (newer) ---"
cd unpacked
find . -type f | sort | xargs shasum -a 256

echo "=== UTC anchor (end) ==="
date -u
echo "=== gcloud auth list (end) ==="
gcloud auth list
